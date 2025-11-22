module Prick::Lang
  module Timer
    def ftime(time, limit: "ms")
      units = %w(s ms μs ns)
      for unit in units
        if time < 1
          if unit == limit
            time = time.round(3)
            break
          end
          time *= 1000
        else
          if time > 100
            time = time.round(0)
          elsif time > 10
            time = time.round(1)
          else
            time = time.round(2)
          end
          break
        end
      end
      return time.to_s + unit
    end

    def time(title, &block)
      t0 = Time.now
      r = yield
      t1 = Time.now
      ShellOpts.verb "#{title} (#{ftime t1 - t0})"
      r
    end
  end
end
