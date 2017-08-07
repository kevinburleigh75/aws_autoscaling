from sqlalchemy import create_engine

from sqlalchemy import (
#     create_engine,
    Table,
#     Column,
#     Integer,
#     String,
#     MetaData,
)

from sqlalchemy.dialects.postgresql import UUID as Uuid
# from sqlalchemy.sql import select

import datetime
import random
import uuid

##
## Create an engine and connect to the db.
##

eng = create_engine('postgresql://aws_autoscaling@localhost/aws_autoscaling_dev_python', echo=True)
con = eng.connect()

##
## Create metadata (schema) by reflection.
##

# meta = MetaData()
# meta.reflect(bind=eng)

##
## Create a declarative base class and bind it to the engine.
##

from sqlalchemy.ext.declarative import declarative_base
Base = declarative_base()
Base.metadata.bind = eng

##
## Monitor column reflection events, and automatically map
## the table columns to object attributes.  (Only do this
## for the declaritive base created above.)
##

from sqlalchemy import event
@event.listens_for(Table, "column_reflect")
def column_reflect(inspector, table, column_info):
    if table.metadata is Base.metadata:
        # set column.key = "attr_<lower_case_name>"
        column_info['key'] = "c_%s" % column_info['name'].lower()
        print('{:20s} --> {:20s}'.format(column_info['name'], column_info['key']))


##
## Monitor session before_commit events so
## that created_at and updated_at columns
## are always correctly populated.  Doing this
## on the client-side is susceptible to clock
## drift, but allows TimeCop-like behavior
## for testing.
##

import datetime

from sqlalchemy.orm import sessionmaker
Session = sessionmaker(bind=eng)

from sqlalchemy import event
from itertools import chain
@event.listens_for(Session, "before_commit")
def before_commit(session):
    timestamp = datetime.datetime.now()
    for instance in chain(session.dirty, session.new):
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
    __table__ = Table('protocol_records_python', Base.metadata, autoload=True)#, autoload_with=Base.metadata.bind)

    def __repr__(self):
        return 'ProtocolRecord[{} {} {:03d} {:03d} {} {}]'.format(
            self.c_group_uuid,
            self.c_instance_uuid,
            self.c_instance_count,
            self.c_instance_modulo,
            self.c_created_at,
            self.c_updated_at,
        )

for _ in range(3):
    print('=' * 80)

##
## Clear old records from the db.
##

print('   *** deleting old records ***')

session = Session()

session.query(ProtocolRecord).delete()

session.commit()

##
## Insert some ProtocolRecords into the db.
##

print('   *** creating records ***')

session = Session()

for _ in range(10):
    session.add(ProtocolRecord(
        c_id              = random.randint(1, 1000),
        c_protocol_name   = 'exper',
        c_group_uuid      = str(uuid.uuid4()),
        c_instance_uuid   = str(uuid.uuid4()),
        c_instance_count  = 10,
        c_instance_modulo = random.randint(0, 9),
        c_boss_uuid       = str(uuid.uuid4()),
    ))

# print('-' * 20)
# print('dirty: ' + str(session.dirty))
# print('new:   ' + str(session.new))

session.commit()

import time
time.sleep(0.5)

##
## Update some records.
##

print('   *** updaing records ***')

session = Session()

for instance in session.query(ProtocolRecord) \
                       .filter(ProtocolRecord.c_instance_modulo % 3 == 0) \
                       .order_by(ProtocolRecord.c_group_uuid):
    print(instance)
    instance.c_instance_modulo = -1

session.commit()

##
## Dumping records.
##

print('   *** dumping records ***')

from sqlalchemy.orm import sessionmaker
Session = sessionmaker(bind=eng)
session = Session()

for instance in session.query(ProtocolRecord) \
                       .order_by(ProtocolRecord.c_group_uuid):
    print(instance)

session.commit()

# protocol_table = Table('protocol_records_python', meta, autoload=True)



# protocol = ProtocolRecord()
# print(protocol.instance_uuid)

# current_time = datetime.time()

# instrs = protocol_table.insert().values(
#     id              = random.randint(1, 1000),
#     protocol_name   = 'exper',
#     group_uuid      = str(uuid.uuid4()),
#     instance_uuid   = str(uuid.uuid4()),
#     instance_count  = 6,
#     instance_modulo = 2,
#     boss_uuid       = str(uuid.uuid4()),
# )

# con.execute(instrs)

# sel = select([protocol_table])
# rows = con.execute(sel)

# for row in rows:
#     print(row)

# con.close()
