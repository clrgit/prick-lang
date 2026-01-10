
require_relative './ext/bash.rb'
require_relative './ext/graph.rb'
require_relative './ext/semver.rb'
require_relative './ext/tree.rb'
require_relative './ext/x_array.rb'
require_relative './ext/debug.rb' # Debug
require_relative './ext/trace.rb' # Debug

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
require_relative './lang/unit.dump.rb'

module Prick::Lang
  class TokenizerError < Error; end
  class EofError < Error; end # Not an error but used as a signal

  # Supported dump kinds
  DUMP_KINDS = %w(tokens ast idr refs deps units state)

  # Used to dump tokens as they are processed. The problem is that the kind of
  # a token depends on the context so we need to run the parser to get the
  # right interpretation
  def self.install_token_listener(tokens)
    Token.alias_method(:orig_initialize, :initialize)
    Token.define_method(:initialize) { |*args| orig_initialize(*args); tokens << self; }
  end

  def self.dump(compiler, kinds)
    compiler.load_compiler_state
    state = kinds.delete "state" # We want state to be last
    if kinds.empty?
      compiler.parse
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
    # Tokens are captured as they are read by the tokenizer (and ultimately the
    # parser). They don't have a data structure of their own so instead we
    # install a listener to register them as they are created
    tokens = []
    install_token_listener(tokens) if kinds.include? "tokens"

    # Tokens and ast
    compiler.parse
    dump_tokens(tokens) if kinds.delete "tokens"
    compiler.ast.dump if kinds.delete "ast"
    return if kinds.empty?

    # Converter. FIXME Explain strange result if run before analyzer
    compiler.convert

    # Analyzer
    compiler.analyzer.analyze
    compiler.idr.dump if kinds.delete "idr" # FIXME Should be moved before #analyze

    compiler.analyzer.dump if kinds.delete "analyzer"
    compiler.analyzer.dumpsource if kinds.delete "source"
    compiler.analyzer.dumpfiles if kinds.delete "files"
    compiler.analyzer.dumpnodes if kinds.delete "nodes"
    compiler.analyzer.dumpresources if kinds.delete "resources"
    compiler.analyzer.dumpschemas if kinds.delete "schemas"

    compiler.dumpdeps if kinds.delete "deps"
    compiler.dumpreqs if kinds.delete "reqs"
    compiler.dumprefs if kinds.delete "refs"
    return if kinds.empty?

    # Generator
    compiler.generate
    compiler.generator.dump if kinds.delete "generator"
    puts compiler.units.map(&:to_s) if kinds.delete "units"

    kinds.empty? or ShellOpts.error "Illegal dump option '#{kinds.first}'"
  end

  def self.dump_tokens(tokens)
    puts "Tokens"
    indent { puts tokens.map(&:to_s) }
  end
end

require_relative './lang/compiler.rb'
require_relative './lang/compiler.dump.rb'
require_relative './lang/reader.rb'
require_relative './lang/tokenizer.rb'
require_relative './lang/parser.rb'
require_relative './lang/evaluator.rb'
require_relative './lang/converter.rb'
require_relative './lang/analyzer.rb'
require_relative './lang/analyzer.dump.rb'
require_relative './lang/generator.rb'
require_relative './lang/generator.dump.rb'
require_relative './lang/executer.rb'

