#require 'simplecov'
#SimpleCov.start

# frozen_string_literal: true

#require "prick/lang.rb"
require "prick.rb"

#using String::Text

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  # config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Get rid of eye-stressing cyan
  config.detail_color = :blue
end

# Local modifications

# Silence most of the output from pending tests. See https://github.com/rspec/rspec-core/issues/2377
module FormatterOverrides
  def example_pending(n)
    colorizer=::RSpec::Core::Formatters::ConsoleCodes
    output << current_indentation \
           << colorizer.wrap(n.example.description, :pending) \
           << "\n"
  end

  def dump_pending(_)
  end
end

RSpec::Core::Formatters::DocumentationFormatter.prepend FormatterOverrides

# Debug include
require "string-text"

using String::Text

require './lib/prick/lang/ast.sig.rb'
require './lib/prick/lang/idr.sig.rb'

require './spec/capture_helper.rb'
require './spec/compiler_helper.rb'

#Trace.enable

