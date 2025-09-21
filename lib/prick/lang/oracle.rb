
module Prick::Lang
  class Oracle
    forward_to :@hash, :empty?, :key?, :each

    def initialize
      @hash = {}
    end

    def [](uid)
      key?(uid) ? @hash[uid] : (@hash[uid] = nil)
    end

    def []=(uid, present)
      constrain present, true, false, nil
      !key?(uid) or raise ArgumentError "Duplicate key"
      @hash[uid] = present
    end

    # Return uids of true/false/nil entries
    def truths = @hash.filter_map { _2 and _1 }
    def falses = @hash.filter_map { ! _2 and _1 }
    def unknowns = @hash.filter_map { _2.nil? and _1 }
  end
end

