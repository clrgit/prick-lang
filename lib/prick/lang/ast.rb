
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
    end

    class Program < Node
      attr_accessor :block
      def initialize(file)
        super nil, Token.new(file, 1, 1, "", :PROGRAM)
      end
    end

    # Block has a nil ident. Token may be nil; it defaults to #start_token
    class Block < Node
      def token = empty? ? nil : start_token # We check empty? to avoid endless recursion in #start_token
      alias_method :stmts, :children
    end

    class Decl < Node
      forward_to :token, :kind
#     forward_to :ident, :name
      attr_accessor :ident
      attr_accessor :block

      def buildtree = @children << ident << block
    end

    class Require < Node
      alias_method :refs, :children # [Reference]
    end

    class Phase < Node
      def name = @token.text
      attr_accessor :block
    end

    class Command < Node
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

#   # Just to make #dump easier to read
#   class ElsifThen < IfThen
#   end
#
#   # Just to make #dump easier to read
#   class Else < Block
#   end

    class Case < Node
      attr_accessor :const # Const
      attr_accessor :whens # [When]
      attr_accessor :else_ # Block
    end

    class When < Node
      attr_accessor :values # [Value]
      attr_accessor :then_ # Block
    end

    class Expr < Node
    end

    # @token is the operator in expression objects
    class UnExpr < Expr
      def oper = @token.text
      def expr = children.first
    end

    class BinExpr < Expr
      def oper = @token.text
      def lexpr = children.first
      def rexpr = children.last
    end

    class SimpleExpr < Expr
    end

    class RuntimeExpr < SimpleExpr
      alias_method :words, :children # [Ident]
    end

    # eg. 'schema app'
    class ReferenceExpr < SimpleExpr
      def ref = children.first # Reference
    end

    class VersionExpr < SimpleExpr # the 'version' keyword. See Ver
      alias_method :matches, :children # [VersionCompare]
    end

    class Value < Node
    end

    class File < Value
      forward_to :@token, :filename, :extname
    end

    class Ident < Value
      def name = @token.text
    end

    class Reference < Value
      def ref = @token.text
    end

    class Ver < Value # a version value. See Version
      def version = @token.text # for now
    end

    class VersionMatch < Value
      def oper = @token.text
      def version = @children.first
    end

    class Const < Node
      def name = @token.text
    end
  end
end

