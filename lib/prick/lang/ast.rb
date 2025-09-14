
module Prick::Lang
  module Ast
    class Node < Part; end
    class Nodes < Node; end
    class Stmt < Node; end
    class Block < Stmt; end
    class Program < Node; end
    class Decl < Stmt; end
    class Provide < Stmt; end
    class Require < Stmt; end
    class Phase < Stmt; end
    class Command < Stmt; end
    class Source < Command; end
    class ExternalCommand < Command; end
    class CallCommand < Command; end
    class If < Stmt; end
    class IfThen < Node; end
    class Case < Stmt; end
    class When < Node; end
    class Expr < Node; end
    class UnExpr < Expr; end
    class BinExpr < Expr; end
    class SimpleExpr < Expr; end
    class RuntimeExpr < SimpleExpr; end
    class ReferenceExpr < SimpleExpr; end
    class VersionExpr < SimpleExpr; end
    class VersionMatch < Node; end
    class Value < Node; end
    class File < Value; end
    class Reference < Value; end
    class Ver < Value; end
    class Ident < Value; end
    class Word < Value; end
    class Const < Value; end

    class Node < Part
      def self.classname = self.to_s.sub(/.*::/, "")
      def classname = self.class.classname

      attr_reader :parent # Node or nil
      attr_reader :children # [Node] mostly initialized by the analyzer

      forward_to :@children, :empty?

      # All nodes have a start and stop token (they can be the same). The start
      # token is equal to #token by default

      # All nodes have a token that identifies the node and a start and stop
      # token. The three tokens are often identical but eg. binary operators
      # have three different tokens: '1 + 2' yields '1' as the start token, '2'
      # as the stop token, and '+' as the binary expression token
      attr_accessor :token

      # Start token defaults recursively to the start token of the first child
      def start_token() @start_token ||= @children.first&.start_token || @token end
      attr_writer :start_token

      # Stop token defaults recursively to the stop token of the last child
      def stop_token() @stop_token ||= @children.last&.stop_token || @token end
      attr_writer :stop_token

      forward_to :token, :lineno, :charno, :kind, :file

      def initialize(token)
        constrain token, Token, nil
        @token = token
        Tree.initialize(self)
        super()
      end
    end

    # Array of nodes. Token may be nil; it defaults to #start_token
    class Nodes < Node
      # Redefine token to default to #start_token. We check empty? to avoid
      # endless recursion in #start_token
      def token = @token || (empty? ? nil : start_token)

      attr_reader :element_klass

      def initialize(token, element_klass)
        super token
        @element_klass = element_klass
      end

      forward_to :@children, :each, :map

      def <<(node)
        !node.nil? or raise ArgumentError
        node.class <= element_klass or
            raise ArgumentError, "Expected #{element_klass.classname}, got #{node.classname}"
        self.attach node
      end
    end

    class Stmt < Node
    end

    # A block is an Nodes object with elements restricted to statements
    class Block < Stmt
      part :stmts, [Stmt]
    end

    class Program < Node
      part :block, Block
      def initialize(file)
        super Token.new(file, 1, 1, "", :PROGRAM)
      end
    end

    class Decl < Stmt
      forward_to :token, :kind # Symbol
      part :ident, Ident
      part :block, Block
    end

    class Provide < Stmt
      part :ident, Ident
    end

    class Require < Stmt
      part :refs, [Reference]
    end

    class Phase < Stmt
      def name = @token.text
      part :block, Block
    end

    class Command < Stmt; end

    # Sequence of .sql/.psql files
    class Source < Command
      part :files, [File]
    end

    # exec/eval
    class ExternalCommand < Command
      attr_accessor :source # Array of source lines. Assigned after initialization

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/
    end

    # call
    class CallCommand < Command
      part :refs, [Reference]
    end

    class If < Stmt
      part :if_thens, [IfThen]
      part :else_, Block
    end

    class IfThen < Node
      part :expr, Expr
      part :then_, Block
    end

    class Case < Stmt
      part :const, Const
      part :whens, [When]
      part :else_, Block
    end

    class When < Node
      part :values, [Value]
      part :then_, Block
    end

    class Expr < Node
    end

    # @token is the operator in expression objects
    class UnExpr < Expr
      def oper = @token.text
      part :expr, Expr
    end

    class BinExpr < Expr
      def oper = @token.text
      part :lexpr, Expr
      part :rexpr, Expr
    end

    class SimpleExpr < Expr
    end

    class RuntimeExpr < SimpleExpr
      part :words, [Ident]
    end

    # eg. 'schema app'
    class ReferenceExpr < SimpleExpr
      part :ref, Reference
    end

    class VersionExpr < SimpleExpr # the 'version' keyword. See Ver
      part :matches, [VersionMatch]
    end

    class VersionMatch < Node
      def oper = @token.text
      part :version, Ver
    end

    class Value < Node
      def value = @token.text
      def literal = @token.text
      def to_s = value.to_s
    end

    class File < Value
      forward_to :@token, :path, :dirname, :filename, :extname
      def value = @token.path
    end

    class Reference < Value
    end

    class Ver < Value # a version value. See Version
      def value() @value ||= Semver.new(literal) end
    end

    class Ident < Value
    end

    class Word < Value
    end

    class Const < Value
    end
  end
end







