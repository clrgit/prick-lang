
module Fmt
  # Print table
  def self.puts_table(headers, table, bold: nil)
    widths = headers.map(&:size)
    signs = []
    types = []
    indexes = [] # absolute position of column. Zero based
    for i in (0...headers.size)
      value_width =
          table.map { |row|
            case value = row[i]
              when TrueClass, FalseClass
                types[i] = 's'
                signs[i] = '-'
                5
              when NilClass
                types[i] = 's'
                signs[i] = '-'
                4
              when String
                types[i] = 's'
                signs[i] = '-'
                value.split("\n").map(&:size).max || 0
              when Integer
                types[i] = 'i'
                signs[i] = ''
                Math.log10(value) + 1
              when Array
                types[i] = 's'
                signs[i] = '-'
                all_size = value.join(' ').size
                if all_size < 60
                  all_size
                else
                  value.map(&:size).max
                end
              when Semver
                types[i] = 's'
                signs[i] = '-'
                value.to_s.size
            else
              raise ArgumentError, "Illegal value: '#{value}' (#{value.class})"
            end
          }.max || 0
      widths[i] = [widths[i], value_width].max
      indexes[i] = (i == 0 ? 0 : indexes[i-1] + widths[i-1] + 1)
    end

    for width, value in widths.zip(headers)
      printf "%-#{width}s ", value
    end
    puts

    widths.each.with_index { |width, index|
      char = (headers[index] =~ /^\s*$/ ? " " : "-")
      printf "%#{width}s ", char * width
    }
    puts

    table.each.with_index { |row, rownum|
#     for index, sign, width, type, value in signs.zip(indexes, signs, widths, types, row) # FIXME doesn't work?
      print "\033[1m" if rownum == bold

      for i in (0...headers.size)
        index, sign, width, type, value = indexes[i], signs[i], widths[i], types[i], row[i]

        if value && value =~ /\n/m
          value = value.split("\n")
          print value.first
          for line in value[1..]
            puts
            print "#{' ' * index}#{line}"
          end
        elsif value.is_a?(Array)
          values = value.dup
          lines = []
          while !values.empty?
            rest = width
            line = []
            while !values.empty? && values.first.size <= rest
              rest -= values.first.size
              line << values.shift
            end
            lines << line.join(" ")
          end
          print lines.first
          for line in lines[1..] || []
            puts
            print "#{' ' * index}#{line}"
          end
        else
          value = (value.nil? ? "-" : value)
          printf "%#{sign}#{width}#{type} ", "#{value}"
        end
      end
      puts (rownum == bold ? "\033[0m" : "")
    }
  end
end

