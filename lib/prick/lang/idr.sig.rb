
module Prick::Lang::Idr
  class Resource
    def sig
      block.each { |node| node.dump }
    end
  end
end
