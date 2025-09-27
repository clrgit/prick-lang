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
require_relative './lang/ext/trace.rb' # Debug
require_relative './lang/common.rb'
require_relative './lang/error.rb'

require_relative './lang/token.rb'
require_relative './lang/part.rb'
require_relative './lang/ast.rb'
require_relative './lang/ast.dump.rb'
require_relative './lang/idr.rb'
require_relative './lang/oracle.rb'

module Prick::Lang
  class Error < StandardError; end
  class InternalError < Error; end
  class TokenizerError < Error; end
  class EofError < Error; end # Not an error but used as a signal

  def self.install_token_listener(tokens)
    Token.alias_method(:orig_initialize, :initialize)
    Token.define_method(:initialize) { |*args| orig_initialize(*args); tokens << self; }
  end

  DUMP_KINDS = %w(tokens ast idr oracle)

  def self.dump(file, lines = nil, kind, variables)
    tokenizer = Tokenizer.new(file, lines)
    parser = Parser.new(tokenizer)
    case kind
      when "token", "tokens"
        tokens = []
        install_token_listener(tokens)
        parser.parse
        puts "Processed #{tokens.size} tokens"
        indent { tokens.each &:dump }

      when "ast", nil
        parser.parse.dump
#       Ast::Node.dump_model

      when "idr", "oracle"
        oracle = Oracle.new({ cmd: "build", env: "prod", user: "me" }.merge(variables))
        analyzer = Analyzer.new(parser, oracle)
        parser.parse
        if kind == "idr"
          analyzer.analyze.dump
        else
          analyzer.analyze_ast
          oracle.dump
        end

    else
      raise ArgumentError
    end
  end
end

require_relative './lang/tokenizer.rb'
require_relative './lang/parser.rb'
require_relative './lang/evaluator.rb'
require_relative './lang/analyzer.rb'
#require_relative 'lang/generator.rb'
require_relative './lang/compiler.rb'
