
drop function if exists prick.get_serial(varchar) cascade;
drop function if exists prick.get_serial(varchar, varchar) cascade;
drop procedure if exists prick.update_serials() cascade;

create function prick.get_serial(table_uid varchar) returns integer as $$
  declare
    max_id integer;
  begin
    execute '
      select
        case is_called when true then last_value + 1 else last_value end as "next_value"
      from ' || pg_get_serial_sequence($1, 'id')
    using table_uid
    into max_id;
    return max_id;
  end;
$$ language plpgsql;

create function prick.get_serial(schema_name varchar, table_name varchar) returns integer as $$
  select prick.get_serial(schema_name || '.' || table_name);
$$ language sql;

-- Update prick.serials with current values from the prick.curr_serials view
create procedure prick.sync_serials() as $$
  begin
    delete from prick.serials;
    insert into prick.serials (schema_name, table_name, sequence_name, value)
        select schema_name, table_name, sequence_name, value from prick.curr_serials
  end;
$$ language plpgsql;

/*
set search_path to prick;

drop procedure if exists update_serials(varchar);
drop procedure if exists update_serial(varchar);
drop function if exists get_serial(varchar);
drop procedure if exists set_serial(varchar, integer);

-- Get current serial for the given table. The current serial is the _next_
-- value that will be returned
create function get_serial(table_uid varchar) returns integer as $$
  declare
    max_id integer;
  begin
    execute '
      select
        case is_called when true then last_value + 1 else last_value end as "next_value"
      from ' || pg_get_serial_sequence($1, 'id')
    using table_uid
    into max_id;
    return max_id;
  end;
$$ language plpgsql;

-- Set the table's ID counter to the given value or '1' if absent
create procedure set_serial(_table_uid varchar, _id integer default null) as $$
  begin
    execute '
      select setval(
          pg_get_serial_sequence($1, ''id''),
          coalesce($2, 1),
          false
        )
      from ' || _table_uid
    using _table_uid, _id;
  end;
$$ language plpgsql;

-- Update serial on a table to the max id plus one
create procedure update_serial(table_uid varchar) as $$
  begin
    execute '
      select setval(
          pg_get_serial_sequence($1, ''id''),
          coalesce(max(id), 1),
          max(id) is not null
        )
      from ' || table_uid
    using table_uid;
  end;
$$ language plpgsql;

-- Update serials on all tables in the given schema to the max id plus one
create procedure update_serials(schema_name varchar) as $$
  declare
    table_name varchar;
  begin
    for table_name in
      select t.table_name from information_schema.tables t where table_schema = schema_name
    loop
      call lib.update_serial(schema_name || '.' || table_name);
    end loop;
  end;
$$ language plpgsql;

*/
