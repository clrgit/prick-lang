
-- Contains only the most recent record from builds
create view states as
  select *
  from builds
  where created_at = (select max(created_at) from builds)
;

-- Current serial values for each table
create view prick.curr_serials as
  with serials as (
    select
      table_schema::varchar as "schema_name",
      table_name::varchar,
      pg_get_serial_sequence(format('%I.%I', table_schema, table_name), column_name) as "sequence_name"
    from information_schema.columns
    where column_name = 'id'
  )
  select
    s.*,
    prick.get_serial(schema_name || '.' || table_name) as "value"
  from serials s
  where sequence_name is not null
;

