require 'indented_io'


# Currently used to avoid polluting Kernel with helper methods
module Trace
  def self.render_arg(arg)
    arg.is_a?(Hash) ? arg.to_s[1..-2] : arg.inspect
  end

  def self.render_args(*args, **opts)
    if args.empty? && opts.empty?
      ""
    else
      values = (args.map(&:inspect) + [opts.empty? ? nil : opts.to_s[1..-2]])
      "(" + values.compact.join(", ") + ")"
    end
  end
end

trace = TracePoint(:return) { |tp|
  puts "Method: #{tp.method_id}"
}
trace.enable

module Kernel
  @@TRACES = []

  def trace(*args, **opts)
    stack = caller.map { |l| l =~ /^.*:.*:in `(\w+)'$/; $1 }.compact
    function = stack.first

#   if function == "analyze_provide"
#     $stderr.puts "-----------------------------------"
#     $stderr.puts "> stack"
#     $stderr.indent { |f| f.puts stack }
#     $stderr.puts "> function: #{function.inspect}"
#     $stderr.puts "> @@TRACES: #{@@TRACES.inspect}"
#   end

    if @@TRACES.first == function
      @@TRACES.shift
      undent
    end

    traces = []
    trace_i = 0
    for entry in stack
      if entry == @@TRACES[trace_i]
        traces << entry
        trace_i += 1
      end
    end

    undent_levels = @@TRACES.size - traces.size
    @@TRACES = [function] + traces
#   if function == "analyze_provide"
#     $stderr.puts "> @@TRACES: #{@@TRACES.inspect}"
#   end
    undent_levels.times { Kernel.undent }

    puts "##{function}#{Trace.render_args *args, **opts}"
    Kernel.indent
  end

  def retrace
    @@TRACES.size.times { Kernel.undent }
    @@TRACES = []
  end
end

