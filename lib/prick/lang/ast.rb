module Prick::Lang
  module Ast
    class Node
      attr_reader :parent # Node or nil
      attr_reader :children # [Node]
      attr_reader :token

      forward_to :token, :lineno, :charno, :kind

      def initialize(parent, token)
        constrain parent, Node, nil
        constrain token, Token
        @parent = parent and parent.children << self
        @children = []
        @token = token
      end

      def inspect() = "#<#{self.class}>"

      def dump_ident = puts sig_ident
      def dump_attrs = nil

      def dump
        print "#{self.class.to_s.sub(/.*::/, "")} "
        dump_ident
        dump_attrs
        indent { children.each &:dump }
      end

      def sig_ident = ""
      def sig = sig_ident.empty? ? "#{token.kind}" : "#{token.kind} #{sig_ident}"
    end

    class Program < Node
      def initialize(file)
        super(nil, Token.new(file, 1, 1, "", :PROGRAM))
      end
    end

    class Decl < Node
      attr_accessor :name
      attr_accessor :block

      def initialize(parent, token, name)
        constrain token.kind, *Parser::GRAMMAR_GROUPS[:decl]
        constrain name, String
        super parent, token
        @name = name
      end

      def sig_ident = name.inspect
    end

    class Phase < Node
      attr_accessor :block

      def initialize(parent, token)
        constrain token.kind, *Parser::GRAMMAR_GROUPS[:phase]
        super parent, token
      end

      def sig_ident = ""
    end

    class Command < Node
      def kind = token.kind
      attr_accessor :source # Array of source lines. Assigned after initialization

      def initialize(parent, token, source = nil)
        constrain token.kind, *Parser::GRAMMAR_GROUPS[:command]
        constrain source, Array, nil
        super parent, token
      end

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/

      def sig_ident
        source.split("\n").join("; ")
      end

      def dump_ident
        if multiline?
          puts kind
          indent { puts source }
        else
          puts sig_ident
        end
      end
    end

    class Block < Node
      def name = @token.text
      alias_method :start_token, :token
      attr_accessor :stop_token, :token
      def initialize(parent, start_token, stop_token = start_token)
        constrain stop_token, Token
        super(parent, start_token)
        @stop_token = stop_token
      end
    end

    class FileStmt < Node
      forward_to :token, :filename, :extname
      def sig_ident = filename
    end



    class If < Node
      attr_reader :expr # Expr
      attr_accessor :then_ # Block
      attr_accessor :else_ # Block

      def initialize(parent, token, expr, then_ = nil, else_ = nil)
        super(parent, token)
        @expr, @then_, @else_ = expr, then_, else_
      end

      def dump
        puts "If #{expr}"
        indent { then_.dump }
        if else_
          puts "else"
          indent { else_.dump }
        end
      end

      def analyze(parent) Idr::IfStmt.new(self, parent, expr, @then.analyze, @else.analyze) end
    end







    class InitBlock < Block
    end

    class FinalBlock < Block
    end

    class MetaBlock < Block #?
    end

    class SeedBlock < Block
    end

    class AuthBlock < Block
    end

    class SchemaStmt < Node
    end

    class OptionStmt < Node
    end

    class CaseStmt < Node
      attr_reader :expr
      attr_reader :when_entries # {expr => Node}
      attr_reader :else_entry # Node or nil
    end

    class CallStmt < Node
      # Single-line command or multiline inline script
      attr_reader :source # String

      # True if source is a multiline inline script
      def multiline?() end

#     # Shell command if single-line, otherwise nil
#     def command() end

      # True if calling a ruby script using require, default false
      attr_reader :ruby
    end

    class ExecStmt < CallStmt
    end

    class EvalStmt < CallStmt
    end

    class SqlFileStmt < FileStmt
    end

    class PSqlFileStmt < FileStmt
    end

    class FoxFileStmt < FileStmt
    end

    class RubyFileStmt < FileStmt # ?
      def analyze() CallStmt.new(self, filename, ruby: true) end
    end

    class DirStmt < FileStmt
    end

    class PrickStmt < FileStmt
    end

    class InitBlock
    end

    class Expr < Node
    end
  end
end
