require 'indented_io'

module Trace
  @@TRACERS = {}
  @@TRACER_COUNTS = {}
  @@ENABLED = false

  def self.enabled? = @@ENABLED
  def self.enable() @@ENABLED = true end
  def self.disable() @@ENABLED = false end

  def self.key(klass, method) = "#{klass}##{method}"

  def self.create_tracer(key)
    @@TRACER_COUNTS[key] = 0
    @@TRACERS[key] = TracePoint.new(:return) { |tp|
      key = "#{tp.defined_class}##{tp.method_id}"
      @@TRACER_COUNTS[key] -= 1
      if @@TRACER_COUNTS[key] == 0
        @@TRACERS[key].disable # self.disable ?
      end
      Kernel.undent
    }
  end

  def self.ensure_tracer(key)
    create_tracer(key) if ! @@TRACERS.key?(key)
  end

  def self.enable_tracer(key, klass, method)
    @@TRACERS[key].enable(target: klass.instance_method(method)) if @@TRACER_COUNTS[key] == 0
    @@TRACER_COUNTS[key] += 1
  end

  def self.disable_tracer(key)
    @@TRACER_COUNTS[key] -= 1
    @@TRACERS[key].disable if @@TRACER_COUNTS[key] == 0
  end

  def self.render_arg(arg)
    arg.is_a?(Hash) ? arg.to_s[1..-2] : arg.inspect
  end

  def self.render_args(*args, **opts)
    if args.empty? && opts.empty?
      ""
    else
      values = (args.map(&:inspect) + [opts.empty? ? nil : opts.to_s[1..-2]])
      "(" + values.flatten.compact.join(", ") + ")"
    end
  end
end

module Kernel
  def trace(*args, **opts)
    return if !Trace.enabled?
    stack = caller.map { |l| l =~ /^.*:.*:in `(\S+)'$/; $1 }
    name = stack.first
    method = stack.first
    klass = self.class

    key = "#{klass}##{method}"
    Trace.ensure_tracer(key)
    Trace.enable_tracer(key, klass, method)

    puts "##{name}#{Trace.render_args *args, **opts}"
    Kernel.indent
  end
end

