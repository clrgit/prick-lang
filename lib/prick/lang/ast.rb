
module Prick::Lang
  module Ast
    class Node < Part
      include ClassFunctions

      attr_reader :parent # Node or nil
      attr_reader :children # [Node]

      forward_to :@children, :empty?

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
        super()
      end
    end

    # Array of nodes. Token may be nil, defaults to #start_token
    class Nodes < Node
      include Parts
      def initialize(token, element_klass)
        super(token)
        Parts.initialize(self, element_klass)
      end
    end

    #
    # V A L U E S
    #

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

    class VersionMatch < Value
      def oper = @token.text
      part :version, Ver
    end

    class Ident < Value
      def to_sym = @token.text.to_sym
    end

    class Word < Value
    end

    class Const < Value
    end

    #
    # E X P R E S S I O N S
    #

    class Expr < Node
    end

    # @token is the operator in expression objects
    class UnExpr < Expr
      def oper = @token.kind
      part :expr, Expr
    end

    class BinExpr < Expr
      def oper = @token.kind
      part :lexpr, Expr
      part :rexpr, Expr
    end

    class SimpleExpr < Expr
    end

    # cmd, env, user
    class RuntimeExpr < SimpleExpr
      part :ident, Ident
      part :words, [Ident]
    end

    # schema, object, resource
    class ReferenceExpr < SimpleExpr
      part :ref, Reference # TODO: Rename reference
    end

    class VersionExpr < SimpleExpr # the 'version' keyword. See Ver
      part :matches, [VersionMatch]
    end

    #
    # S T A T E M E N T S
    #

    class Stmt < Node
    end

    # A block is an Nodes object with elements restricted to statements
    class Block < Stmt
      part :stmts, [Stmt]
    end

    class Provide < Stmt
      part :ident, Reference # Always initialized with a single identifier
    end

    class Require < Stmt
      part :references, [Reference]
    end

    #
    # D E C L A R A T I O N S
    #

    class Decl < Stmt
      part :ident, Reference
      part :block, Block
    end

    class Function < Decl
    end

    class Phase < Function
    end

    class Schema < Decl
    end

    #
    # C O M M A N D S
    #

    class Command < Stmt; end

    # Sequence of .sql/.psql files
    class Source < Command # TODO: Rename FileCommand
      part :files, [File]
    end

    # exec/eval/sql
    class ExternalCommand < Command
      attr_accessor :source # Array of source lines. Assigned after initialization

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/
    end

    # call function
    class CallCommand < Command
      part :refs, [Reference]
    end

    #
    # C O N T R O L   S T A T E M E N T S
    #

    class Control < Stmt; end

    class IfThen < Node
      part :expr, Expr
      part :then_, Block
    end

    class If < Control
      part :if_thens, [IfThen]
      part :else_, Block
    end

    class When < Node
      part :values, [Value]
      part :then_, Block
    end

    class Case < Control
      part :const, Const
      part :whens, [When]
      part :else_, Block
    end

    #
    # P R O G R A M
    #

    class Program < Node
      part :block, Block
      def initialize(file)
        super Token.new(file, 1, 1, "", :PROGRAM)
      end
    end
  end
end







