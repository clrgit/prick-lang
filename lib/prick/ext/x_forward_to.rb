require 'forward_to'

module ForwardTo
  def forward_to_s(target, *methods) = impl_forward_to_s(target, methods, class_method: false)

private
  def impl_forward_to_s(target, *methods, class_method: false)
    qual = class_method ? "self." : ""
    for method in Array(methods).flatten
      case method
        when /\[\]=/, /=$/
          raise ArgumentError
        else
          var = :"@__forward_to_s__#{method}"
          class_eval %(
            def #{qual}#{method}
              return nil if target.nil?
              return #{var} if !#{var}.nil?
              value = #{target}.#{method}(*args, &block)
              return nil if value.nil?
              #{var} = value.is_a?(Array) ? value.map(&:to_s) : value.to_s
            end
          )
      end
    end
  end
end


