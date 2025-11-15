--
-- ChatGPT ...
--

/*
I would like a function with the following description:

A plpgsql procedure that updates records in a target table with
records in a merge table. The two tables are joined using a join field that is
a unique key in both tables. Records in the target table that are absent in the
merge table are deleted, records in the merge table that are absent in the
target table are created, and records present in both tables are updated with
the content from the merge table

It should have the following signature

  merge(target_table: text, target_records: integer[], merge_table: text, unique_field: text)

and be used like this

  call merge('auth.users', (select id from auth.users where kind = 'USER'), 'dev_auth.users', 'rolename');
*/

create or replace procedure sync(
  target_table text,
  target_records integer[],
  merge_table text,
  unique_field text
)
language plpgsql
as $$
declare
  sql text;
  set_clause text;
begin
  -- delete rows in target not in merge
  sql := format($f$
    delete from %1$I t
    where t.%2$I = any(%3$L)
      and not exists (
        select 1 from %4$I m
        where m.%2$I = t.%2$I
      );
  $f$, target_table, unique_field, target_records, merge_table);
  execute sql;

  -- insert absent rows in target
  sql := format($f$
    insert into %1$I
    select m.*
    from %2$I m
    where not exists (
      select 1 from %1$I t
      where t.%3$I = m.%3$I
    );
  $f$, target_table, merge_table, unique_field);
  execute sql;

  -- build column list for update (exclude id and unique_field)
  select string_agg(format('t.%1$I = m.%1$I', a.attname), ', ')
  into set_clause
  from pg_attribute a
  where a.attrelid = target_table::regclass
    and a.attnum > 0
    and not a.attisdropped
    and a.attname not in ('id', unique_field);

  -- update rows existing in both
  sql := format($f$
    update %1$I t
    set %2$s
    from %3$I m
    where m.%4$I = t.%4$I;
  $f$, target_table, set_clause, merge_table, unique_field);
  execute sql;
end;
$$;

call sync(
  'auth.users',
  array(select id from auth.users where kind = 'USER'),
  'dev_auth.users',
  'rolename'
);

create or replace procedure sync(
  target_table text,
  target_record_id_table text,
  merge_table text,
  unique_field text
)
language plpgsql
as $$
declare
  target_ids integer[];
  sql text;
begin
  -- build an array of ids from the supplied table name
  sql := format('select array_agg(id) from %I', target_record_id_table);
  execute sql into target_ids;

  if target_ids is null or array_length(target_ids, 1) is null then
    raise notice 'no ids found in %', target_record_id_table;
    target_ids := '{}';
  end if;

  -- call the main sync procedure
  call sync(target_table, target_ids, merge_table, unique_field);
end;
$$;


