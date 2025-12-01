
module FileUtils
  # :dir should be an absolute path (default is the current path)
  def self.upfind(file, dir = Dir.getwd)
    dir = upfinddir(file, dir) and File.join(dir, file)
  end

  def self.upfinddir(file, dir = Dir.getwd)
    return "" if defined?(RSpec) # RSpec compatibility
    dir = dir ? File.absolute_path(dir) : Dir.getwd
    while dir != "/" && !File.exist?(File.join dir, file)
      dir = File.dirname(dir)
    end
    dir == "/" ? nil : dir
  end
end

