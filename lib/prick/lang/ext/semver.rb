
class Semver
  include Comparable

  # Major part
  def major() @impl[0] end
  def major=(i) @impl[0] = i end

  # Minor part. Can be nil
  def minor() @impl[1] end
  def minor=(i) @impl[1] = i end

  # Patch part. Can be nil and must be nil if minor is nil
  def patch() @impl[2] end
  def patch=(i) 
    @impl[1] ||= 0
    @impl[2] = i
  end

  def initialize(*args) 
    s = args.join(".")
    s =~ /^(\d+)(?:\.(\d+)(?:\.(\d+))?)?$/ or
      raise ArgumentError, "Illegal argument: #{args.inspect}"
    @impl = [$1.to_i, $2&.to_i, $3&.to_i]
  end

  def truncate(part = :patch) self.dup.truncate!(part) end
  def truncate!(part = :patch)
    case part
      when :major; @impl = [0, nil, nil]
      when :minor; @impl = [major, nil, nil]
      when :patch; @impl = [major, minor, nil]
    else
      raise ArgumentError
    end
    self
  end

  # Assign zero to minor and patch if undefined. #extend is the opposite of
  # #truncate
  def extend(part = :patch) self.dup.extend!(part) end
  def extend!(part = :patch)
    case part
      when :major; # nop
      when :minor; @impl = [major, minor || 0, nil]
      when :patch; @impl = [major, minor || 0, patch || 0]
    else
      raise ArgumentError
    end
    self
  end

  def increment(part) self.dup.increment!(part) end
  def increment!(part)
    case part
      when :major; @impl = [major + 1, minor && 0, patch && 0]
      when :minor; @impl = [major, (minor || 0) + 1, patch && 0]
      when :patch; @impl = [major, minor || 0, (patch || 0) + 1]
    else
      raise ArgumentError
    end
    self
  end

  def <=>(r) 
    r = Semver.new(r) if !r.is_a?(Semver)
    self.extend.to_a <=> r.extend.to_a 
  end
  
  def squiggle?(r)
    r = Semver.new(r) if !r.is_a?(Semver)
    r.minor or raise ArgumentError
    begin_version = r
    end_version = (r.patch ? r.increment(:minor) : r.increment(:major))
    begin_version <= self && self < end_version
  end

  def to_s() @impl.compact.join(".") end
  def to_a() @impl end

  def inspect() to_s end

  ZERO = Semver.new(0, 0, 0)
end

class SemverMinor
  attr_reader :minor
end

class SemverPatch
end

__END__

class Semver
  def +(relver) end
  def -(semver) end
end

# It doesn't make sense to have a delta with multiple parts since changes in a
# preceding part will set subsequent parts to zero
class SemverDelta
  include Comparable

  def +(delta) 
    
  end
  def +(version) end

  def <=>() end
end

__END__

module Prick
  class Semver
  end

  class Minor
  end

  class Patch
  end
end


    class Semver
      include Comparable
      def major() @impl[0] end
      def minor() @impl[1] end
      def patch() @impl[2] end
      def initialize(s) 
        s =~ /\d+\.\d+\.\d+/ or
          raise "Unrecognized version string: #{s.inspect}"
        @impl = s.split('.').map { |e| e.to_i }
      end
      def hash() @impl.hash end
      def eql?(r) self == r end
      def <=>(r) @impl <=> r.to_a end
      def to_s() @impl.join('.') end
      def to_a() @impl end
    end

# "require 'semantic'" is moved to lib/prick.rb to avoid having Gem depend on it
# require 'semantic' # https://github.com/jlindsey/semantic

# Required by gem
module Prick
  VERSION = "0.18.0"
end

# Project related code starts here
module Prick
  class Semver
    class FormatError < RuntimeError; end

    include Comparable

    PRE_LABEL = "pre"
    PRE_RE = /^#{PRE_LABEL}\.(\d+)$/

    def self.zero() Semver.new("0.0.0") end
    def zero?() self == Semver.zero end

    # Return true if `string` is a version
    def self.version?(string) 
      string.is_a?(String) or raise Internal, "String expected"
      !(string =~ VERSION_RE).nil? 
    end

    attr_accessor :fork
    attr_accessor :semver
    attr_accessor :feature

    def major() @semver.major end
    def major=(major) @semver.major = major end

    def minor() @semver.minor end
    def minor=(minor) @semver.minor = minor end

    def patch() @semver.patch end
    def patch=(patch) @semver.patch = patch end

    # Return true if this is a fork release
    def fork?() !@fork.nil? end

    # Return true if this is a feature release
    def feature?() !@feature.nil? end

    # Return true if this is a release branch (and not a prerelease)
    def release?() !feature? && !pre? end

    # Return true if this is a pre-release
    def pre?() !@semver.pre.nil? end
    def prerelease?() pre? end

    # The releases is stored as a String (eg. 'pre.1') in the semantic version
    # but #pre returns only the Integer number
    def pre() @semver.pre =~ PRE_RE ? $1.to_i : nil end
    def prerelease() pre end

    # #pre= expects an integer or nil argument
    def pre=(pre) @semver.pre = (pre ? "#{PRE_LABEL}.#{pre}" : nil) end
    def prerelease=(pre) self.pre = pre end

    def dup() Semver.new(self) end
    def clone() Semver.new(self) end

    def eql?(other) self == other end
    def hash() @semver.hash end

    def initialize(version, fork: nil, feature: nil)
      case version
        when String
          version =~ VERSION_RE or raise Semver::FormatError, "Expected a version, got #{version.inspect}"
          @fork = fork || $1
          @semver = Semantic::Semver.new($3)
          @feature = feature || $4
        when Semantic::Semver
          @fork = fork
          @semver = version.dup
          @feature = feature
        when Semver
          @fork = fork || version.fork
          @semver = version.semver.dup
          @feature = feature || version.feature
      else
        raise Internal, "Expected a String, Semver, or Semantic::Semver, got #{version.class}"
      end
    end

    # Try converting the string `version` into a Semver object. Return nil if unsuccessful
    def self.try(version)
      version.is_a?(Semver) ? version : (version?(version) ? new(version) : nil)
    end

    # Parse a branch or tag name into a Semver object. Return a [version, tag]
    # tuple where tag is true if name was a tag
    def self.parse(name)
      name =~ VERSION_RE or raise Semver::FormatError, "Expected a version, got #{version.inspect}"
      fork, tag, semver, feature = $1, $2, $3, $4
      version = Semver.new(semver, fork: fork, feature: feature)
      [version, tag]
    end
    # `part` can be one of :major, :minor, :patch, or :pre. If pre is undefined, it 
    # is set to `pre_initial_value`
    def increment(part, pre_initial_value = 1) 
      self.dup.increment!(part, pre_initial_value)
    end

    def increment!(part, pre_initial_value = 1)
      if part == :pre
        self.pre = (self.pre ? self.pre + 1 : pre_initial_value)
      else
        @semver = semver.increment!(part)
      end
      self
    end

    def truncate(part)
      case part
        when :pre
          v = self.dup
          v.feature = nil
          v.pre = nil
          v
        when :feature
          v = self.dup
          v.feature = nil
          v
      else
        raise NotYet
      end
    end

#   def path
#     parts = [FEATURE_DIR, truncate(:pre), feature].compact
#     File.join(*parts)
#   end

#   def link
#     !feature? or raise Internal, "Semver #{to_s} is a feature, not a release"
#     File.join(RELEASE_DIR, to_s)
#   end

    def <=>(other)
      r = (fork || "") <=> (other.fork || "")
      return r if r != 0
      r = semver <=> other.semver
      return r if r != 0
      r = (feature || "") <=> (other.feature || "")
      return r
    end

    # Render as branch
    def to_s(tag: false)
      (fork ? "#{fork}-" : "") + (tag ? "v" : "") + semver.to_s + (feature ? "_#{feature}" : "")
    end

    # Render as a tag
    def to_tag() to_s(tag: true) end

    # Render as string
    def inspect() to_s end
  end
end


