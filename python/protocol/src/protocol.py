from sqlalchemy import create_engine

from sqlalchemy import (
    create_engine,
    Table,
    Column,
    Integer,
    String,
    MetaData,
)

from sqlalchemy.dialects.postgresql import UUID as Uuid
from sqlalchemy.sql import select

import datetime
import random
import uuid

eng = create_engine('postgresql://aws_autoscaling@localhost/aws_autoscaling_dev_python')
con = eng.connect()

meta = MetaData()
meta.reflect(bind=eng)

protocol_table = Table('protocol_records_python', meta, autoload=True)

current_time = datetime.time()

instrs = protocol_table.insert().values(
    id              = random.randint(1, 1000),
    protocol_name   = 'exper',
    group_uuid      = str(uuid.uuid4()),
    instance_uuid   = str(uuid.uuid4()),
    instance_count  = 6,
    instance_modulo = 2,
    boss_uuid       = str(uuid.uuid4()),
)

con.execute(instrs)

sel = select([protocol_table])
rows = con.execute(sel)

for row in rows:
    print(row)

con.close()
