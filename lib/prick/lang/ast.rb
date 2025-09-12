
module Prick::Lang
  module Ast
    class Node
      include Tree

      attr_reader :parent # Node or nil
      attr_reader :children # [Node]

      forward_to :@children, :empty?

      # All nodes have a start and stop token (they can be the same). The start
      # token is equal to #token by default

      # All nodes have a token that identifies the node and a start and stop
      # token.  The three tokens are often identical but eg. binary operators
      # have three different tokens: '1 + 2' yields '1' as the start token, '2'
      # as the stop token, and '+' as the binary expression token
      attr_accessor :token

      # Start token defaults recursively to the start token of the first child
      def start_token() @start_token ||= @children.first&.start_token || @token end
      attr_writer :start_token

      # Stop token defaults recursively to the stop token of the last child
      def stop_token() @stop_token ||= @children.last&.stop_token || @token end
      attr_writer :stop_token

      forward_to :@token, :lineno, :charno, :kind, :file

      def initialize(parent, token)
        constrain token, Token, nil
        initialize_tree parent
        @token = token
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
      forward_to :token, :kind # Symbol
#     forward_to :ident, :name
      attr_accessor :ident
      attr_accessor :block
    end

    class Provide < Node
      def ident = children.first
    end

    class Require < Node
      alias_method :refs, :children # [Reference]
    end

    class Phase < Node
      def name = @token.text
      attr_accessor :block
    end

    class Command < Node; end

    class SourceCommand < Command
      attr_accessor :source # Array of source lines. Assigned after initialization

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/
    end

    class CallCommand < Command
      alias_method :refs, :children
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
      attr_accessor :const # Const
      attr_accessor :whens # [When]
      attr_accessor :else_ # Block
    end

    class When < Node
      attr_accessor :values # [Value]
      attr_accessor :then_ # Block
    end

    class Make < Node
      attr_accessor :dstfiles
      attr_accessor :srcfiles
      attr_accessor :block
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
      def value = raise
    end

    class File < Value
      forward_to :@token, :filename, :extname
    end

    class Reference < Value
      def ref = @token.text
    end

    class Ver < Value # a version value. See Version
      def version = @token.text # for now
      def value() @value ||= SemVer.new(version) end
    end

    class VersionMatch < Value
      def oper = @token.text
      def version = @children.first
    end

    class Ident < Value
      def name = @token.text
    end

    class Word < Value
      def text = @token.text
    end

    class Const < Node
      def name = @token.text
    end
  end
end

