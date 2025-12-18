
class Array
  def top = last

  def pop_while(&block)
    r = []
    while block.call(self.top)
      r << self.pop
    end
    r
  end

  # Returns self[1..-1] as an enumerator. Useful when the first element
  # requires special handling but the rest can be handled in a #each loop
  def rest
    return to_enum(:rest) unless block_given?
    each_with_index { |e, i| yield e if i > 0 }
  end
end

