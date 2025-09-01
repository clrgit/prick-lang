
module Prick::Lang
  module Ast
    class Node
      attr_reader :parent # Node or nil
      attr_reader :children # [Node]
      attr_reader :token

      forward_to :token, :lineno, :charno, :kind

      def initialize(parent, token)
        constrain token, Token
        parent&.attach(self)
        @children = []
        @token = token
      end

      def attach(child)
        return nil if child.nil?
        @children << child
        child.instance_variable_set(:@parent, self)
        child
      end

      def attachs(children)
        @children += children.tap { |c| c.parent = self }
        children
      end

      def classname = "#{self.class}"

      # The node's informal name. This is the class name by default but eg.
      # Command redefines it depending on the kind of command (exec/eval/...).
      # Used in #dump and test
      #
      # Note: Using implicit string conversion instead of #to_s because
      # otherwise encoding would be US-ASCII instead of the application default
      # (usually UTF-8)
      def dumpname = "#{self.class}".sub(/.*::/, "")

      # The node's identifier (possibly nil). Used in #dump and test
      def dumpident = nil

      # Signature of a node (token-kind/class + ident). Used in #dump and test
      def dumpsig = [dumpname, dumpident].compact.join(" ")

      # Dump an Ast node hierarchically
      def dump
        puts dumpsig
        indent { children.each &:dump }
      end

      def inspect() = "#<#{dumpsig}>"
    end

    class Program < Node
      alias_method :stmts, :children
      def initialize(file)
        super nil, Token.new(file, 1, 1, "", :PROGRAM)
      end
    end

    class Decl < Node
      forward_to :token, :kind
      attr_reader :ident
      attr_reader :block

      def name = @ident_token.text

      def initialize(parent, token, ident = nil, block = nil)
        constrain ident, Ident
        constrain block, Block
        super parent, token
        @ident = attach ident
        @block = attach block
      end

      def dumpident = "#{Token::TOKENS[kind]} #{name.inspect}"
    end

    class Phase < Node
      attr_reader :block
      def initialize(parent, token, block)
        constrain block, Block
        super parent, token
        @block = attach block
      end

      def dumpident = Token::TOKENS[kind]
    end

    class Command < Node
      def kind = token.kind
      attr_accessor :source # Array of source lines. Assigned after initialization

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/

      def dumpname = "#{kind}".capitalize
      def dumpident = source.split("\n").join("; ")
    end

    class Block < Node
      def name = @token.text
      alias_method :start_token, :token
      attr_reader :stop_token, :token
      attr_reader :stmts
      def initialize(parent, start_token, stop_token = start_token, stmts)
        constrain stop_token, Token
        constraint stmts, Array
        super parent, start_token
        @stop_token = stop_token
        @stmts = attachs stmts
      end
    end

    class If < Node
      attr_reader :if_thens # List of IfThen nodes
      attr_reader :else_ # Block

      def initialize(parent, token, if_thens, else_)
        constrain if_thens, [IfThen]
        constrain else_, Block, nil
        super parent, token
        @if_thens = attachs if_thens
        @else_ = attach else_
      end

      def dump
        keyword = "If"
        for if_then in if_thens
          puts "#{keyword} #{if_then.expr.source}"
          keyword = "Elsif"
          indent { if_then.then_.dump }
        end
        if else_
          puts "Else"
          indent { else_.dump }
        end
      end

      def analyze(parent) Idr::IfStmt.new(self, parent, expr, @then.analyze, @else.analyze) end
    end

    class IfThen < Node
      attr_reader :expr # Expr
      attr_reader :then_ # Stmts

      def initialize(parent, token, expr, then_)
        constrain expr, Expr
        constrain then_ Block
        super parent, token
        @expr = attach expr
        @then_ = attach then_
      end
    end

    class Expr < Node
      def oper = @token.text

      def source = oper
      def dump = puts source
    end


    # @token is the operator in expression objects
    class UnExpr < Expr
      attr_reader :expr
      def initialize(parent, token, expr)
        constrain expr, Expr
        super parent, token
        @expr = attach(expr)
      end

      def source = "#{oper} #{expr.source}"
    end

    class BinExpr < Expr
      attr_reader :lexpr
      attr_reader :rexpr
      def initialize(parent, token, lexpr, rexpr)
        constrain lexpr, Expr
        constrain rexpr, Expr
        super parent, token
        @lexpr = attach lexpr
        @rexpr = attach rexpr
      end

      def source = "#{lexpr.source} #{oper} #{rexpr.source}"
    end

    class ListExpr < Expr
      def name = @token.name
      attr_reader :idents # List of Idents
      def initialize(parent, token, idents)
        contrain ident, [Idents]
        super parent, token
        @list = attachs idents
      end

      def source = "#{oper} #{list.join(" ")}"
    end

    class VersionExpr < Expr # Token is the 'version' keyword
      attr_reader :exprs
      def initialize(parent, token, exprs)
        constrain exprs, [VersionCompareExpr]
        super parent, token
        @exprs = attachs exprs
      end
    end

    class VersionCompareExpr
      def operator = @token.kind
      attr_reader :version
      def initialize(parent, token, version)
        constrain version, Ver
        super parent, token
        @version = attach version
      end
    end

    class File < Node
      forward_to :token, :filename, :extname
      def dumpident = filename
#     def initialize(parent = nil, token)
#       super(parent, token)
#     end
    end

    class Ident < Node
      def name = token.text
    end

    class Ver < Node
      def source = token.text
      def version = source # For now
    end

  end
end

__END__



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

    class SqlFile < File
    end

    class PSqlFile < File
    end

    class FoxFile < File
    end

    class RubyFile < File # ?
      def analyze() CallStmt.new(self, filename, ruby: true) end
    end

    class DirStmt < File
    end

    class PrickStmt < File
    end

    class InitBlock
    end

    class Expr < Node
    end
  end
end
