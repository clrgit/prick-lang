
module Prick::Lang
  module Ast
    class Node
      attr_reader :parent # Node or nil
      attr_reader :children # [Node]

      forward_to :@children, :empty?

      # All nodes have a start and stop token (they can be the same). The start token is equal to #token by default

      # All nodes have an eigen token and a start/stop token. The three tokens
      # are often identical but eg. binary operators have three different
      # tokens: '1 + 2' yields '1' as the start token, '2' as the stop token,
      # and '+' as the binary expression token
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
        child.is_a?(Node) or raise InternalError
        @children << child
        child.instance_variable_set(:@parent, self)
        child
      end

      def attachs(*children)
        children = Array(children).flatten
        children.all? { _1.is_a?(Node) } or raise InternalError
        @children += children.tap { |c| c.instance_variable_set(:@parent, self) }
        children
      end

      def classname = self.class.to_s.sub(/.*::/, "")
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
      alias_method :stmts, :children
    end

    class Decl < Node
      forward_to :token, :kind
      forward_to :ident, :name
      attr_accessor :ident
      attr_accessor :block
    end

    class Require < Node
      alias_method :refs, :children # [Reference]
    end

    class Phase < Node
      def name = @token.text
      attr_accessor :block
    end

    class Command < Node
      def kind = token.kind
      attr_accessor :source # Array of source lines. Assigned after initialization

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/
    end

    class If < Node
      attr_accessor :if_thens # [IfThen]
      attr_accessor :else_ # Block

      def analyze(parent) Idr::IfStmt.new(self, parent, expr, @then.analyze, @else.analyze) end
    end

    class IfThen < Node
      attr_accessor :expr # Expr
      attr_accessor :then_ # Block
    end

    class Case < Node
      attr_accessor :var # VarExpr
      attr_accessor :whens # [When]
      attr_accessor :else_ # Block
    end

    class When < Node
      attr_accessor :values # [Value]
      attr_accessor :then_ # Block
    end

    class Expr < Node
      def source = @token.text
    end

    # @token is the operator in expression objects
    class UnExpr < Expr
      def oper = @token.text
      def expr = children.first
      def source = "#{oper}(#{expr.source})"
    end

    class BinExpr < Expr
      def oper = @token.text
      def lexpr = children.first
      def rexpr = children.last
#     attr_accessor :lexpr
#     attr_accessor :rexpr
      def source = "#{oper}(#{lexpr.source}, #{rexpr.source})"
    end

    class SimpleExpr < Expr
      def name = @token.text
    end

    class RuntimeExpr < SimpleExpr
      attr_accessor :words # [Token]
      def source = "#{name}(#{words.map(&:text).join(', ')})"
    end

    # eg. 'schema app'
    class ReferenceExpr < SimpleExpr
      def ref = children.first # Reference
      def source = "#{name}(#{ref.ref})"
    end

    class VersionExpr < SimpleExpr # the 'version' keyword. See Ver
      alias_method :matches, :children # [VersionCompare]
      def source = "#{name} #{matches.map(&:dumpsig).join(' ')}"
    end

    class VersionMatch < Node
      def oper = @token.text
      def version = @children.first
    end

    class Var < Node
      def name = @token.text
    end

    class Ident < Node
      def name = @token.text
    end

    class Reference < Node
      def ref = @token.text
    end

    class File < Node
      forward_to :@token, :filename, :extname
    end

    class Ver < Node # a version value. See Version
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
