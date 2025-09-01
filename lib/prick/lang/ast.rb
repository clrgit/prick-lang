
module Prick::Lang
  module Ast
    class Node
      attr_reader :parent # Node or nil
      attr_reader :children # [Node]

      forward_to :@children, :empty?

      # All nodes have a start and stop token (they can be the same). The start token is equal to #token by default

      # All nodes have an eigen token and a start/stop token. The three tokens
      # is often identical but eg. binary operators have three different
      # tokens: '1 + 2' yields '1' as the start token, '2' as the stop token,
      # and '+' as the binary node token
      attr_accessor :token

      # Start token defaults recursively to the start token of the first child
      def start_token() @start_token ||= @children.first&.start_token || @token end
      attr_writer :start_token

      # Stop token defaults recursively to the stop token of the last child
      def stop_token() @stop_token ||= @children.last&.stop_token || @token end
      attr_writer :stop_token

      forward_to :@token, :lineno, :charno, :kind

      def initialize(parent, token)
        constrain token, Token, nil
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
      def dump(nodes = children)
        puts dumpsig
        indent { nodes.each &:dump }
      end

      def inspect() = "#<#{dumpsig}>"
    end

    class Program < Node
      attr_accessor :block
      def initialize(file)
        super nil, Token.new(file, 1, 1, "", :PROGRAM)
      end
    end

    # Block allows the token to be nil. It defaults to #start_token
    class Block < Node
      def name = @token.text
      attr_accessor :block
      alias_method :stmts, :children
    end

    class Decl < Node
      forward_to :token, :kind
      attr_accessor :ident
      attr_accessor :block

      forward_to :ident, :name

      def dumpident = "#{Token::TOKENS[kind]} #{name.inspect}"
      def dump = super([block])

    end

    class Phase < Node
      attr_accessor :block

      def dumpident = Token::TOKENS[kind]
    end

    class Command < Node
      def kind = token.kind
      attr_accessor :source # Array of source lines. Assigned after initialization

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/

      def dumpname = "#{kind}".capitalize
      def dumpident = source ? source.split("\n").join("; ") : ""
    end

    class If < Node
      attr_accessor :if_thens # [IfThen]
      attr_accessor :else_ # Block

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
      attr_accessor :expr # Expr
      attr_accessor :then_ # [Stmt]
    end

    class Expr < Node
      def oper = @token.text
      def source = oper
      def dump = puts source
    end


    # @token is the operator in expression objects
    class UnExpr < Expr
      attr_accessor :expr
      def source = "#{oper} #{expr.source}"
    end

    class BinExpr < Expr
      attr_accessor :lexpr
      attr_accessor :rexpr
      def source = "#{lexpr.source} #{oper} #{rexpr.source}"
    end

    class ListExpr < Expr
      forward_to :@token, :name
      attr_accessor :idents # List of Idents
      def source = "#{oper} #{list.join(" ")}"
    end

    class VersionExpr < Expr # Token is the 'version' keyword
      attr_accessor :exprs
    end

    class VersionCompareExpr
      def operator = @token.kind
      attr_accessor :version
    end

    class File < Node
      forward_to :token, :filename, :extname
      def dumpident = filename
    end

    class Ident < Node
      def name = token.text
      def dumpsig = name
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
