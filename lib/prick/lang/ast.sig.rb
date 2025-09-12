
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

    class Decl
      def signame = "#{Token::TOKENS[kind]} #{ident.name.inspect}"
      def sig = super([block])
    end

    class Provide
      def signame = ident.name
      def sig = puts sigtitle
    end

    class Require
      def sig
        puts "#{sigtitle} #{refs.map(&:ref).join(", ")}"
      end
    end

    class Phase
      def signame = Token::TOKENS[kind]
    end

    class SourceCommand
      def sigclass = kind.to_s.capitalize
      def signame = source ? source.split("\n").join("; ") : ""
    end

    class CallCommand
      def sigclass = kind.to_s.capitalize
      def sig = puts "#{sigtitle} #{refs.map(&:ref).join(", ")}"
    end

    class If
      def sig
        keyword = "If"
        for if_then in if_thens
#         $stderr.puts if_then.class
#         $stderr.puts if_then.expr.class
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
      def source = "#{kind} #{matches.map(&:sigtitle).join(' ')}"
    end

    class Value
    end

    class File
      def signame = filename
    end

    class Ident
      def sigtitle = token.text
    end

    class Reference
      def signame = token.text
      def sigtitle = "Reference(#{token.text.inspect})"
    end

    class Ver
      def signame = token.text
      def sigtitle = "Ver(#{token.text.inspect})"
    end

    class VersionMatch
      def sigtitle = "#{oper}(#{version.signame.inspect})"
    end

    class Const
      def signame = name.upcase
    end
  end
end

