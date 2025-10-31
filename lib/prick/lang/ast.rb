
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
    # E X P R E S S I O N S
    #

    class Expr < Node
    end

    # @token is the operator in expression objects
    class UnaryExpr < Expr
      def oper = @token.kind # Symbol
      part :expr, Expr
    end

    class BinaryExpr < Expr
      def oper = @token.kind
      part :lexpr, Expr
      part :rexpr, Expr
    end

    class ParenExpr < Expr
      part :expr, Expr
      def elems = [@expr] # Quacks like a list
    end

    class ListExpr < Expr
      part :elems, [Expr]
    end

    class WhenExpr < Expr # Quacks like a BinaryExpr
      attr_reader :oper
      def lexpr = whole.expr
      part :rexpr, Expr # Only Value objects are allowed atm.
      def initialize(token)
        super(token)
        @oper = @token.is_oper? ? @token.kind : :EQ
      end
    end

#   class MakeExpr < Expr # Quack like a UnaryExpr
#     attr_reader :
#   end

    #
    # V A L U E S
    #

    class Value < Expr
      def value = @token.text
      def literal = @token.text
      def to_s = value.to_s
    end

    # Note that File does not include prick files. Prick files are represented
    # as Source objects
    class File < Value
      forward_to :@token, :path, :dirname, :filename, :extname
      def value = @token.path
    end

    class Path < Value
      forward_to :@token, :path
      def value = @token.path
    end

    class Ident < Value
      def to_sym = @token.text.to_sym
    end

    class Reference < Value
      attr_accessor :uid
    end

    class Bool < Value
      def value = (@token.text == "true")
    end

    class Ver < Value # a version value. See Version
      def value() @value ||= Semver.new(literal) end
    end

    class Word < Value
    end

    class Var < Value
      def value() token.name.to_sym end
      def to_s = @token.text
    end

    # Belongs to the Expr section but moved here because it depends on Path
    class MakeExpr < Expr
      part :paths, [Path]
      def token = start_token
      def initialize = super(nil)
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

    # A prick source file. Eg. 'make.prick'
    class Source < Stmt
      part :file, [File]
      part :block, Block
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

    class Phase < Decl
    end

    class Schema < Decl
    end

    class Program < Decl
      def initialize(file)
        super Token.new(file, 1, 1, "public", :PROGRAM)
      end
    end

    #
    # C O M M A N D S
    #

    class Command < Stmt; end

    # Sequence of .sql/.psql files
    class FileCommand < Command
      part :file, File
    end

    # exec/eval/sql
    class ExternalCommand < Command
      attr_reader :kind
      attr_accessor :source # Array of source lines. Assigned after initialization

      def initialize(token, kind = nil) super(token); @kind = kind || token.kind end

      # True iff source consists of multiple lines
      def multiline? = @source =~ /\n/
    end

#   class MakeCommand < ExternalCommand # The exec-part when using 'make ... | ...'
#     attr_reader :kind
#     def initialize(token) super(token); @kind = :EXEC end
#   end

    class CallCommand < Command
      part :references, [Reference]
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
      attr_reader :oper
      part :exprs, [WhenExpr]
      part :then_, Block
    end

    class Case < Control
      part :expr, Expr
      part :whens, [When]
      part :else_, Block
    end

    class Make < Control
      part :expr, MakeExpr
      part :then_, Block
    end
  end
end







