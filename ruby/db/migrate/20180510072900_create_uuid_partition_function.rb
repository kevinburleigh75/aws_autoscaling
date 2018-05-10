class CreateUuidPartitionFunction < ActiveRecord::Migration[5.1]
  def up
    connection.execute(%q{
      create function uuid_partition(uuid) returns integer
        as 'select (''x'' || right($1::text, 7))::bit(28)::int;'
        language sql
        immutable
        returns NULL on NULL INPUT;
    })
  end

  def down
    connection.execute(%q{
      drop function if exists uuid_partition(uuid);
    })
  end
end
