# frozen_string_literal: true

require_relative "lang/version"

require 'set'
require 'pathname'

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
require_relative './lang/ext/x_array.rb'
require_relative './lang/ext/time.rb'
require_relative './lang/ext/trace.rb' # Debug
require_relative './lang/common.rb'
require_relative './lang/error.rb'

require_relative './lang/token.rb'
require_relative './lang/part.rb'
require_relative './lang/ast.rb'
require_relative './lang/ast.dump.rb'
require_relative './lang/idr.rb'
require_relative './lang/idr.dump.rb'
require_relative './lang/unit.rb'

module Prick::Lang
  class Error < StandardError; end
  class InternalError < Error; end
  class TokenizerError < Error; end
  class EofError < Error; end # Not an error but used as a signal

  # Supported dump kinds
  DUMP_KINDS = %w(tokens ast idr deps state units)

  # Used to dump tokens as they are processed. The problem is that the kind of
  # a token depends on the context so we need to run the parser to get the
  # right interpretation
  def self.install_token_listener(tokens)
    Token.alias_method(:orig_initialize, :initialize)
    Token.define_method(:initialize) { |*args| orig_initialize(*args); tokens << self; }
  end

  def self.dump(kind, file, lines = nil, targets, exclude, variables)
    compiler = Compiler.new(file, targets, exclude: exclude, variables: variables)
    case kind
      when "tokens"
        tokens = []
        install_token_listener(tokens)
        compiler.parse(file, lines)
        puts "Processed #{tokens.size} tokens"
        indent { puts tokens } # FIXME DUPLICATES in OUTPUT
#       indent { tokens.each &:dump }

      when "ast", nil
        compiler.parser.parse(file, lines)
        compiler.ast.dump

      when "idr", "deps", "state", "units"
        compiler.parse(file, lines)
        compiler.convert
        compiler.analyze
        case kind
          when "idr"; compiler.idr.dump
          when "deps"; compiler.analyzer.dump
          when "state"; compiler.dump
          when "units"
            compiler.generate
            compiler.generator.dump
        end

    else
      raise ArgumentError
    end
  end
end

require_relative './lang/reader.rb'
require_relative './lang/tokenizer.rb'
require_relative './lang/parser.rb'
require_relative './lang/evaluator.rb'
require_relative './lang/converter.rb'
require_relative './lang/analyzer.rb'
require_relative './lang/generator.rb'
require_relative './lang/compiler.rb'


