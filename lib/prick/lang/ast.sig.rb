
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

      # Signature of a node (token-kind/class + ident). Used in #sig and test
      def sigtitle = [sigclass, signame].compact.join(" ")

      # Dump an Ast node hierarchically
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
        puts "#{sigtitle} #{references.map(&:value).join(", ")}"
      end
    end

    class Program
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
      def sig = puts "#{sigtitle} #{references.map(&:value).join(", ")}"
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
        puts "Case #{const.signame}"
        indent {
          for when_ in whens
            puts "When #{when_.values.map(&:sigtitle).join(", ")}"
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
#     def source = @token.text # FIXME FIXME FIXME
    end


    # @token is the operator in expression objects
    class UnExpr
#     def source = "#{oper}(#{expr.source})"
      def source = "#{Token::TOKENS[oper]}(#{expr.source})"
    end

    class BinExpr
      def source = "#{Token::TOKENS[oper]}(#{lexpr.source}, #{rexpr.source})"
    end

    class SimpleExpr
#     def source = @token.text # ???
    end

    class RuntimeExpr
      def source = "#{kind}(#{words.map(&:value).join(', ')})"
    end

    class ReferenceExpr
      def sig = source
      def source = "#{kind}(#{ref.value})"
    end

    class VersionExpr
      def source = "#{kind} #{matches.map(&:sigtitle).join(' ')}"
    end

    class Value
      def signame = value
    end

    class File
      def signame = filename
    end

    class Ident
    end

    class Reference
      def sigtitle = "Reference(#{token.text.inspect})"
    end

    class Ver
      def sigtitle = "Ver(#{token.text.inspect})"
    end

    class VersionMatch
      def sigtitle = "#{oper}(#{version.value})"
    end

    class Const
      def signame = value.upcase
    end
  end
end

