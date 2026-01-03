
set search_path to prick, pg_temp;

-- Contains only the most recent record from runs
create view prick.states as
  select *
  from prick.runs
  where created_at = (select max(created_at) from runs)
;

-- Current serial values for each table
create view prick.curr_serials as
  with serial_wo_values as (
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
  from serial_wo_values s
  where sequence_name is not null
;

