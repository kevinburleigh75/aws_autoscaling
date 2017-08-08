from sqlalchemy import (
    create_engine,
    event,
    Table,
)
from sqlalchemy.dialects.postgresql import UUID as Uuid
from sqlalchemy.ext.declarative     import declarative_base
from sqlalchemy.orm                 import sessionmaker

import datetime
import itertools

##
## Create an engine and connect to the db.
##

eng = create_engine(
    'postgresql://aws_autoscaling@localhost/aws_autoscaling_dev_python',
    # echo = True, ## output SQL to console
)
con = eng.connect()

##
## Create a declarative base class and bind it to the engine.
##

Base = declarative_base()
Base.metadata.bind = eng

##
## Monitor column reflection events, and automatically map
## the table columns to object attributes.  (Only do this
## for the declaritive base created above.)
##

@event.listens_for(Table, 'column_reflect')
def column_reflect(inspector, table, column_info):
    if table.metadata is Base.metadata:
        column_info['key'] = 'c_%s' % column_info['name'].lower()
        print('{:20s} --> {:20s}'.format(column_info['name'], column_info['key']))


##
## Monitor session before_commit events so
## that created_at and updated_at columns
## are always correctly populated.  Doing this
## on the client-side is susceptible to clock
## drift, but allows TimeCop-like behavior
## for testing.
##

Session = sessionmaker(bind=eng)

@event.listens_for(Session, 'before_commit')
def before_commit(session):
    timestamp = datetime.datetime.now()
    for instance in itertools.chain(session.dirty, session.new):
        if hasattr(instance, 'c_created_at'):
            if instance.c_created_at is None:
                instance.c_created_at = timestamp
        if hasattr(instance, 'c_updated_at'):
            instance.c_updated_at = timestamp

        if hasattr(instance, 'created_at'):
            if instance.created_at is None:
                instance.created_at = timestamp
        if hasattr(instance, 'updated_at'):
            instance.updated_at = timestamp

##
## Create a class to represent an entry in the protocol_records_pyhton table.
##

class ProtocolRecord(Base):
    __table__ = Table('protocol_records_python', Base.metadata, autoload=True)

    def __repr__(self):
        return 'ProtocolRecord[{} {} {:03d} {:03d} {} {}]'.format(
            self.c_group_uuid,
            self.c_instance_uuid,
            self.c_instance_count,
            self.c_instance_modulo,
            self.c_created_at,
            self.c_updated_at,
        )

##
## Create a class to implement the protocol.
##

import random
import time
import uuid

class Protocol:
    def __init__(self,
                 protocol_name,
                 min_work_interval,
                 min_boss_interval,
                 work_modulo,
                 work_offset,
                 group_uuid,
                 work_block,
                 boss_block,
                 session_class):
        self.protocol_name     = protocol_name
        self.min_work_interval = min_work_interval
        self.min_boss_interval = min_boss_interval
        self.work_modulo       = work_modulo
        self.work_offset       = work_offset
        self.group_uuid        = group_uuid
        self.work_block        = work_block
        self.boss_block        = boss_block
        self.session_class     = session_class
        self.instance_uuid     = str(uuid.uuid4())


    def _compute_next_work_time(self, last_time, current_time, instance_count, instance_modulo):
        if last_time is None:
            ct = current_time - datetime.datetime.fromtimestamp(0, datetime.timezone.utc)
            wm = self.work_modulo
            last_time = current_time - (ct % wm) + self.work_offset + self.min_work_interval/instance_count*instance_modulo

        next_time = last_time + self.min_work_interval
        return next_time


    def run(self):
        try:
            next_boss_time       = None
            next_work_time       = None
            prev_instance_count  = None
            prev_instance_modulo = None

            self.session = self.session_class()

            while True:
                my_record, group_records, dead_records = self._read_records()
                if my_record is None:
                    print('create!')
                    self._create_record()
                    continue

                am_boss, boss_record = self._get_boss_situation(group_records)
                # print('-' * 20)
                # print('my_record   = {}'.format(my_record))
                # print('boss_record = {}'.format(boss_record))
                # print('am_boss     = {}'.format(am_boss))

                if boss_record is None:
                    print('elect!')
                    self._elect_new_boss(my_record, group_records)
                    continue

                if not am_boss:
                    next_boss_time = None

                my_record.c_boss_uuid      = boss_record.c_boss_uuid
                my_record.c_instance_count = len(group_records)
                self._save_record(my_record)

                if am_boss and (0 != len(dead_records)):
                    print('destroy!')
                    self._destroy_dead_records(dead_records)
                    continue

                actual_modulos = sorted(list(map(lambda rec: rec.c_instance_modulo, group_records)))
                target_modulos = sorted(list(range(boss_record.c_instance_count)))
                # print('actual_modulos = {}'.format(sorted(actual_modulos)))
                # print('target_modulos = {}'.format(sorted(target_modulos)))

                if actual_modulos != target_modulos:
                    print('allocate needed!')
                    if (my_record.c_instance_modulo < 0) or (my_record.c_instance_modulo >= boss_record.c_instance_count):
                        print('allocate myself!')
                        self._allocate_modulo(my_record, group_records)
                    time.sleep(0.1)
                    continue

                current_time = datetime.datetime.now(datetime.timezone.utc)

                if am_boss and ( (next_boss_time is None) or (current_time >= next_boss_time) ):
                    next_boss_time = current_time + self.min_boss_interval
                    self.boss_block(
                        instance_uuid   = self.instance_uuid,
                        instance_count  = boss_record.c_instance_count,
                        instance_modulo = my_record.c_instance_modulo,
                    )

                if ( (next_work_time is None) or (my_record.c_instance_modulo != prev_instance_modulo) or (boss_record.c_instance_count != prev_instance_count) ):
                    next_work_time = self._compute_next_work_time(
                        last_time       = None,
                        current_time    = current_time,
                        instance_count  = boss_record.c_instance_count,
                        instance_modulo = my_record.c_instance_modulo,
                    )
                    prev_instance_count  = boss_record.c_instance_count
                    prev_instance_modulo = my_record.c_instance_modulo

                if current_time >= next_work_time:
                    self.work_block(
                        instance_uuid   = self.instance_uuid,
                        instance_count  = boss_record.c_instance_count,
                        instance_modulo = my_record.c_instance_modulo,
                        am_boss         = am_boss,
                    )

                    current_time = datetime.datetime.now(datetime.timezone.utc)
                    next_work_time = self._compute_next_work_time(
                        last_time       = next_work_time,
                        current_time    = current_time,
                        instance_count  = boss_record.c_instance_count,
                        instance_modulo = my_record.c_instance_modulo,
                    )
                else:
                    if am_boss:
                        sleep_interval = min([datetime.timedelta(seconds=0.5), next_work_time - current_time, next_boss_time - current_time]).total_seconds()
                    else:
                        sleep_interval = min([datetime.timedelta(seconds=0.5), next_work_time - current_time]).total_seconds()
                    time.sleep(sleep_interval)
        except KeyboardInterrupt as ex:
            print('exiting')
        except Exception as ex:
            raise ex
        finally:
            self.session.rollback()
            my_records = self.session.query(ProtocolRecord) \
                                     .filter_by(c_instance_uuid = self.instance_uuid) \
                                     .all()
            for record in my_records:
                self.session.delete(record)
            self.session.commit()


    def _read_records(self):
        all_records = self.session.query(ProtocolRecord) \
                                  .filter_by(c_group_uuid = self.group_uuid) \
                                  .all()

        current_time = datetime.datetime.now(datetime.timezone.utc)
        delta_time   = datetime.timedelta(seconds=10)

        group_records = list(filter(lambda rec: rec.c_updated_at > current_time - delta_time, all_records))
        dead_records  = list(set(all_records) - set(group_records))
        my_record     = next((rec for rec in all_records if rec.c_instance_uuid == self.instance_uuid), None)

        return (my_record, group_records, dead_records)


    def _create_record(self):
        retries = 0

        while True:
            modulo = -1000 - random.randint(1,1000)

            try:
                # session = self.session_class()
                protocol_record = ProtocolRecord(
                    c_protocol_name   = 'exper',
                    c_group_uuid      = self.group_uuid,
                    c_instance_uuid   = self.instance_uuid,
                    c_instance_count  = 1,
                    c_instance_modulo = modulo,
                    c_boss_uuid       = self.instance_uuid,
                )
                self.session.add(protocol_record)
                self.session.commit()
                break

            except Exception as ex:
                retries += 1
                print('retrying ({}): {}'.format(retries, ex))
                if retries >= 20:
                    raise Exception('failed after {} retries'.format(retries))


    def _get_boss_situation(self, group_records):
        records_by_boss_uuid      = itertools.groupby(group_records, lambda rec: rec.c_boss_uuid)
        count_by_boss_uuid        = {kk: len(list(vv)) for kk,vv in records_by_boss_uuid}
        sorted_count_by_boss_uuid = list(reversed(sorted(count_by_boss_uuid.items(), key=lambda kvpair: kvpair[1])))

        uuid, votes = sorted_count_by_boss_uuid[0]

        # print('sorted_count_by_boss_uuid = {}'.format(sorted_count_by_boss_uuid))
        # print('uuid = {} votes = {}'.format(uuid, votes))

        boss_uuid = uuid if votes > len(group_records) / 2 else None
        boss_record = next((rec for rec in group_records if rec.c_instance_uuid == boss_uuid), None)
        am_boss = (boss_uuid == self.instance_uuid)

        return am_boss, boss_record


    def _elect_new_boss(self, my_record, group_records):
        lowest_uuid = sorted(map(lambda rec: rec.c_instance_uuid, group_records))[0]

        my_record.c_boss_uuid      = lowest_uuid
        my_record.c_instance_count = len(group_records)

        self._save_record(my_record)
        time.sleep(0.1)


    def _destroy_dead_records(self, dead_records):
        for record in dead_records:
            self.session.delete(record)
        self.session.commit()


    def _allocate_modulo(self, my_record, group_records):
        am_boss, boss_record = self._get_boss_situation(group_records)
        if boss_record is None:
            print('   boss record is None')
            return

        boss_instance_count = boss_record.c_instance_count

        all_modulos   = set(range(boss_instance_count))
        taken_modulos = set([rec.c_instance_modulo for rec in group_records if 0 <= rec.c_instance_modulo < boss_instance_count])

        available_modulos = all_modulos - taken_modulos

        for target_modulo in available_modulos:
            try:
                my_record.c_instance_modulo = target_modulo
                my_record.c_instance_count  = len(group_records)
                self._save_record(my_record)
                break
            except Exception as ex:
                time.sleep(0.1)

        time.sleep(0.1)


    def _save_record(self, my_record):
        self.session.add(my_record)
        self.session.commit()


class Worker:
    def __init__(self):
        pass

    def do_work(self, instance_uuid, instance_count, instance_modulo, am_boss):
        print('{} {} {:02d}/{:02d} {} doing work'.format(
            datetime.datetime.now(),
            instance_uuid,
            instance_modulo,
            instance_count,
            '*' if am_boss else ' ',
        ))

    def do_boss(self, instance_uuid, instance_count, instance_modulo):
        print('{} {} {:02d}/{:02d} doing boss'.format(
            datetime.datetime.now(),
            instance_uuid,
            instance_modulo,
            instance_count,
        ))


worker = Worker()


protocol = Protocol(
    protocol_name     = 'exper',
    min_work_interval = datetime.timedelta(seconds=1),
    min_boss_interval = datetime.timedelta(seconds=2.5),
    work_modulo       = datetime.timedelta(seconds=1),
    work_offset       = datetime.timedelta(seconds=0),
    group_uuid        = '36ae1120-eb63-451e-8460-ec7dd8151575',
    work_block        = worker.do_work,
    boss_block        = worker.do_boss,
    session_class     = Session,
)

protocol.run()
