# frozen_string_literal: true

require_relative "lib/prick/lang/version"

Gem::Specification.new do |spec|
  spec.name = "prick-lang"
  spec.version = Prick::Lang::VERSION
  spec.authors = ["author name"]
  spec.email = ["author@nowhere.com"]

  spec.summary = "Gem prick-lang"
  spec.description = "Gem prick-lang"
  spec.homepage = "http://www.nowhere.com/"
  spec.required_ruby_version = ">= 3.1.0"


  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "shellopts"
  spec.add_dependency "constrain"
  spec.add_dependency "forward_to"
  spec.add_dependency "indented_io"
  spec.add_dependency "string-text"


  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html

  # Add your production dependencies here
  # spec.add_dependency GEM [, VERSION]

  # Add your development dependencies here
  # spec.add_development_dependency GEM [, VERSION]

  # Also un-comment in spec/spec_helper to use simplecov
  # spec.add_development_dependency "simplecov"
end
