require 'yaml'

module YAML
  def self.load_extended(file, **opts)
    opts[:symbolize_names] = true if !opts.key?(:symbolize_names)
    YAML.load File.read(file).sub(/^__END__\n.*/m, ""), **opts
  end
end

