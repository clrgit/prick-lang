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

require_relative './lang/error.rb'

module Prick::Lang
  class Error < StandardError; end
  class InternalError < Error; end
  class TokenizerError < Error; end
  class EofError < Error; end # Not an error but used as a signal

  class Compiler
    include ErrorFunctions

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
      @tokenizer = Prick::Lang::Tokenizer.new(self)

      puts "Tokenizing #{file}"
      indent {
#       while s = @tokenizer.read_line
#         puts "#{@tokenizer.lineno} #{s}"
#       end

#       while s = @tokenizer.load_buffer
#         puts "#{@tokenizer.lineno} #{s}"
#       end

#       @tokenizer.skip_blanks
#       @tokenizer.dump
#       while token = @tokenizer.read #(:TEXT)
#         p token
#         @tokenizer.dump
#         if @tokenizer.eol?
#           @tokenizer.next_line
#           @tokenizer.skip_blanks
#         end
#
#       end

#       while !@tokenizer.eof?
#         t = @tokenizer.readtext
#         p t
#         @tokenizer.find_line
#       end

#
#       while t = @tokenizer.readline
#         p t
#       end
#

#       while line = @tokenizer.load_buffer
#         puts "#{@tokenizer.lineno} #{line}"
#       end

#       while line = @tokenizer.readline
#         puts "#{@tokenizer.lineno} #{line}"
#       end
      }


    end
  end
end


require_relative './lang/token.rb'
require_relative './lang/ast.rb'
require_relative './lang/ast.dump.rb'
#require_relative './lang/idr.rb'

require_relative './lang/tokenizer.rb'
require_relative './lang/parser.rb'
#require_relative 'lang/analyzer.rb'
#require_relative 'lang/generator.rb'

