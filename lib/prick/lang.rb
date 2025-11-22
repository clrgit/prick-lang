# frozen_string_literal: true

require_relative "lang/version"

require 'stringio'

require 'set'
require 'pathname'
require 'yaml'
require 'time'

require 'constrain'
require 'forward_to'
require 'yaml'
require 'indented_io'
require 'string-text'

include ForwardTo
include Constrain
include IndentedIO

using String::Text

require_relative './lang/ext/semver.rb'
require_relative './lang/ext/tree.rb'
require_relative './lang/ext/x_array.rb'
require_relative './lang/ext/debug.rb'
require_relative './lang/ext/trace.rb' # Debug

require_relative './lang/common.rb'
require_relative './lang/error.rb'
require_relative './lang/timer.rb'

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
  DUMP_KINDS = %w(tokens ast idr links deps marks units state)

  # Used to dump tokens as they are processed. The problem is that the kind of
  # a token depends on the context so we need to run the parser to get the
  # right interpretation
  def self.install_token_listener(tokens)
    Token.alias_method(:orig_initialize, :initialize)
    Token.define_method(:initialize) { |*args| orig_initialize(*args); tokens << self; }
  end

  def self.dump(compiler, kinds)
    compiler.load_state
    state = kinds.delete "state"
    if kinds.empty?
      compiler.parse compiler.file
      compiler.convert
      compiler.analyze
      compiler.generate
    else
      dump_phases(compiler, kinds)
    end
    compiler.dump if state
  end

private
  def self.dump_phases(compiler, kinds)
    tokens = []
    install_token_listener(tokens) if kinds.include? "tokens"

    compiler.parse compiler.file
    dump_tokens(tokens) if kinds.delete "tokens"
    compiler.ast.dump if kinds.delete "ast"
    return if kinds.empty?

    compiler.convert
    compiler.analyzer.analyze link: false
    compiler.idr.dump if kinds.delete "idr"
    return if kinds.empty?

    compiler.analyze link: true
    compiler.idr.dump if kinds.delete "links"
    compiler.analyzer.dump if kinds.delete "deps"
    compiler.analyzer.dump(marks: true) if kinds.delete "marks"
    return if kinds.empty?

    compiler.generate
    compiler.generator.dump if kinds.delete "units"
  end

  def self.dump_tokens(tokens)
    puts "Tokens"
    indent { puts tokens.map(&:to_s) }
  end
end

require_relative './lang/compiler.rb'
require_relative './lang/reader.rb'
require_relative './lang/tokenizer.rb'
require_relative './lang/parser.rb'
require_relative './lang/evaluator.rb'
require_relative './lang/converter.rb'
require_relative './lang/analyzer.rb'
require_relative './lang/generator.rb'
require_relative './lang/executer.rb'

