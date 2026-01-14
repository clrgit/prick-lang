#!/usr/bin/env ruby

require 'pg_conn'

conn = PgConn.new "dev"

conn.insert "a.tbl2", [:name, :count], (1..10).map { |i| ["tbl2[#{i}]", i] }.to_a

#insert into tbl2 (name, count) values ('An entry in A', 42);

