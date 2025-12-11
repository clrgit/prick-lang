require 'yaml'

module YAML
  def self.load_extended(file, **opts)
    opts[:symbolize_names] = true if !opts.key?(:symbolize_names)
    opts[:permitted_classes] = [Time, Symbol]
    YAML.load File.read(file).sub(/^__END__\n.*/m, ""), **opts
  end
end

class Hash
  def to_yaml_extended
    self.transform_keys(&:to_s).to_yaml
  end
end

