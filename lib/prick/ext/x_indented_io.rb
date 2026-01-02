
require 'indented_io'

module Kernel
  def pindent(text, &block)
    if block_given?
      puts text
      indent(&block)
    else
      puts text
      indent
    end
  end
end

