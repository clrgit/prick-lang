
# Generate rspec friendly dumps. Only used when testing
#
# 'sig' is short for 'signature'

module Prick::Lang
  module Ast
    class Node
      # The node's informal name. This is the class name by default
      def sigclass = classname

      # The node's identifier (possibly nil). Used in #sig and test
      def signame = nil

      # Signature of a node (token-kind/class + ident).
      def sigtitle = [sigclass, signame].compact.join(" ")

      # Dump an Ast node hierarchically. #sigtitle is supposed to include the
      # value of the node if this is a leaf node
      def sig(nodes = children)
        puts sigtitle
        indent { nodes.each &:sig }
      end
    end

    class Nodes
      def sig(nodes = children)
        nodes.each &:sig
      end
    end

    class Decl
#     def signame = [Token::TOKENS[kind], ident&.value].join(" ")
      def signame = ident&.value
      def sig = super([block])
    end

    class Provide
      def signame = ident.value
      def sig = puts sigtitle
    end

    class Require
      def sig
        puts "#{sigtitle} #{references.map(&:sigtitle).join(", ")}"
      end
    end

    class Block
      def sig(nodes = children)
        nodes.each &:sig
      end
    end

    class Program
      def sig(nodes = children)
        nodes.each &:sig
      end

#     def signame = "Program"
#     def sig = puts "Program"
    end

    class Source
      def sig(nodes = children) = nodes.each &:sig
    end

    class Phase
      def signame = Token::TOKENS[kind]
    end

    class ExternalCommand
      def sigclass = kind.to_s.capitalize
      def signame = source ? source.split("\n").join("; ") : ""
    end

    class CallCommand
      def sigclass = kind.to_s.capitalize
      def sig = puts "#{sigtitle} #{references.map(&:sigtitle).join(", ")}"
    end

    class If
      def sig
        keyword = "If"
        for if_then in if_thens
          puts "#{keyword} #{if_then.expr.sigtitle}"
          keyword = "Elsif"
          indent {
            if_then.then_.sig
          }
        end
        if else_
          puts "Else"
          indent { else_.sig }
        end
      end
    end

    class Case
      def sig
        puts "Case #{expr.sigtitle}"
        indent {
          for when_ in whens
            puts "When #{when_.exprs.map(&:sigtitle).join(", ")}"
            indent { when_.then_.sig }
          end
        }
        if else_
          puts "Else"
          indent { else_.sig }
        end
      end
    end

    class Expr
      def sigtitle = value
    end

    # @token is the operator in expression objects
    class UnaryExpr
      def sigtitle = "#{Token::TOKENS[oper]}(#{expr.sigtitle})"
    end

    class BinaryExpr
      def sigtitle = "#{Token::TOKENS[oper]}(#{lexpr.sigtitle}, #{rexpr.sigtitle})"
    end

    class WhenExpr
      def sigtitle = "#{Token::TOKENS[oper]}(_, #{rexpr.sigtitle})"
    end

    class ListExpr
      def sigtitle = "(#{elems.map(&:sigtitle).join(', ')})"
    end

    class Value
    end

    class File
      def sigtitle = "File #{token.path}"
    end

    class Reference
      def sigtitle = "Reference(#{token.text})"
    end

    class Ident
    end

    class Ver
#     def sigtitle = "Ver(#{token.text.inspect})"
    end

    class Word
    end

    class Var
      def sigtitle = to_s
    end
  end
end

