
module Prick::Lang
  class Oracle
    forward_to :@hash, :empty?, :key?, :[], :[]=

    def initialize
      @hash = {}
    end

    def []=(uid, value)
      !key?(uid) or raise ArgumentError "Duplicate key"
      @hash[uid] = value
    end

    def truths = @hash.filter_map { _2 and _1 }
    def falses = @hash.filter_map { ! _2 and _1 }
  end
end

