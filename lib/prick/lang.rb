# frozen_string_literal: true

require_relative "lang/version"

require 'set'

require 'constrain'
require 'forward_to'
require 'indented_io'
require 'string-text'

include ForwardTo
include Constrain
include IndentedIO

using String::Text

require_relative './lang/ext/semver.rb'
require_relative './lang/ext/tree.rb'
require_relative './lang/error.rb'

module Prick::Lang
  class Error < StandardError; end
  class InternalError < Error; end
  class TokenizerError < Error; end
  class EofError < Error; end # Not an error but used as a signal
end

require_relative './lang/token.rb'
require_relative './lang/ast.rb'
require_relative './lang/ast.dump.rb'
#require_relative './lang/idr.rb'

require_relative './lang/tokenizer.rb'
require_relative './lang/parser.rb'
require_relative './lang/analyzer.rb'
#require_relative 'lang/generator.rb'
require_relative './lang/compiler.rb'
