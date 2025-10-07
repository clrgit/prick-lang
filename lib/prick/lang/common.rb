
class Class
  def classname = self.to_s.sub(/.*::/, "")
end

module Prick::Lang
  module ClassFunctions
    def classname = self.class.classname
  end
end

