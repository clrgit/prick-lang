
class Array
  def top = last

  def pop_while(&block)
    r = []
    while block.call(self.top)
      r << self.pop
    end
    r
  end
end
