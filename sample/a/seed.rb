#!/usr/bin/env ruby

require 'pg_conn'

conn = PgConn.new "dev"

start = ARGV[0]&.to_i || 0

conn.insert "a.tbl2", [:name, :count], (1..10).map { |i| ["tbl2[#{i}]", start+i-1] }.to_a

