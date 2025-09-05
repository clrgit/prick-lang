

module Prick::Lang
  module Ast
    class Node
      # The node's informal name. This is the class name by default but eg.
      def signame = classname

      # The node's identifier (possibly nil). Used in #sig and test
      def sigident = nil

      # Signature of a node (token-kind/class + ident). Used in #sig and test
      def sigval = [signame, sigident].compact.join(" ")

      # Dump an Ast node hierarchically
      def sig(nodes = children)
        puts sigval
        indent { nodes.each &:sig }
      end

      def inspect() = "#<#{sigval}>"
    end

    class Program
    end

    # Block allows the token to be nil. It defaults to #start_token
    class Block
    end

    class Decl
      def sigident = "#{Token::TOKENS[kind]} #{name.inspect}"
      def sig = super([block])
    end

    class Require
      def sig
        puts "#{sigval} #{refs.map(&:ref).join(", ")}"
      end
    end

    class Phase
      def sigident = Token::TOKENS[kind]
    end

    class Command
      def signame = "#{kind}".capitalize
      def sigident = source ? source.split("\n").join("; ") : ""
    end

    class If
      def sig
        keyword = "If"
        for if_then in if_thens
          puts "#{keyword} #{if_then.expr.source}"
          keyword = "Elsif"
          indent { if_then.then_.sig }
        end
        if else_
          puts "Else"
          indent { else_.sig }
        end
      end
    end

    class Case
      def sig
        puts "Case #{const.sigident}"
        indent {
          for when_ in whens
            puts "When #{when_.values.map(&:sigval).join(", ")}"
            indent { when_.then_.sig }
          end
        }
        if else_
          puts "Else"
          indent { else_.sig }
        end
      end
    end

    class IfThen
    end

    class Expr
#     def source = @token.text # FIXME FIXME FIXME
    end


    # @token is the operator in expression objects
    class UnExpr
      def source = "#{oper}(#{expr.source})"
    end

    class BinExpr
      def source = "#{oper}(#{lexpr.source}, #{rexpr.source})"
    end

    class SimpleExpr
#     def source = @token.text # ???
    end

    class RuntimeExpr
      def source = "#{kind}(#{words.map(&:name).join(', ')})"
    end

    class ReferenceExpr
      def sig = source
      def source = "#{kind}(#{ref.ref})"
    end

    class VersionExpr
      def source = "#{kind} #{matches.map(&:sigval).join(' ')}"
    end

    class File
      def sigident = filename
    end

    class Ident
      def sigval = token.text
    end

    class Reference
      def sigident = token.text
      def sigval = "Reference(#{token.text.inspect})"
    end

    class Ver
      def sigident = token.text
      def sigval = "Ver(#{token.text.inspect})"
    end

    class VersionMatch
      def sigval = "#{oper}(#{version.sigident.inspect})"
    end

    class Const
      def sigident = name.upcase
    end
  end
end

__END__



    class InitBlock
    end

    class FinalBlock
    end

    class MetaBlock
    end

    class SeedBlock
    end

    class AuthBlock
    end

    class SchemaStmt
    end

    class OptionStmt
    end

    class CaseStmt
      attr_reader :expr
      attr_reader :when_entries # {expr => Node}
      attr_reader :else_entry # Node or nil
    end

    class CallStmt
      # Single-line command or multiline inline script
      attr_reader :source # String

      # True if source is a multiline inline script
      def multiline?() end

#     # Shell command if single-line, otherwise nil
#     def command() end

      # True if calling a ruby script using require, default false
      attr_reader :ruby
    end

    class ExecStmt
    end

    class EvalStmt
    end

    class SqlFile
    end

    class PSqlFile
    end

    class FoxFile
    end

    class RubyFile
      def analyze() CallStmt.new(self, filename, ruby: true) end
    end

    class DirStmt
    end

    class PrickStmt
    end

    class InitBlock
    end

    class Expr
    end
  end
end
