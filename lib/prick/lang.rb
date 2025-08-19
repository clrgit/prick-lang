# frozen_string_literal: true

require_relative "lang/version"

require 'constrain'
require 'forward_to'
require 'indented_io'
require 'string-text'

include ForwardTo
include Constrain
include IndentedIO

using String::Text

module Prick::Lang
  class Error < StandardError; end
  class TokenizerError < Error; end
  class InternalError < Error; end

  def error(token, message)
    $stderr.puts "#{token.file} #{token.lineno}:#{token.charno} #{message}"
    exit 1
  end

  class Compiler
    attr_reader :file

    attr_reader :tokenizer
    attr_reader :parser
    attr_reader :analyzer

    attr_reader :ast # Ast::Program
    attr_reader :idr # Idr::Program

    def initialize(file)
      @file = file

    end

    def compile
      # Tokenize


      puts "Compiling #{file}"


    end
  end
end


require_relative './lang/token.rb'
#require_relative './lang/ast.rb'
#require_relative './lang/idr.rb'

require_relative './lang/tokenizer.rb'
#require_relative './lang/parser.rb'
#require_relative 'lang/analyzer.rb'
#require_relative 'lang/generator.rb'
