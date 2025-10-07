
module Prick
  module Lang
    class Checker
      using String::Text
      include ErrorFunctions

      def initialize
      end

      def check(ast)
        check_nesting
        true
      end

      NESTING = {
        Ast::Schema => [Ast::Function, Ast::Phase],
        Ast::Function => [],
        Ast::Phase => []
      }

      def check_nesting
        ast.trees(NESTING.keys).each { |node|
          ast.trees(NESTING.keys).each { |subnode|
            NESTING[node.class].include? subnode.class or
                error node, "#{subnode.classname} can't be nested within a #{node.classname}"
          }
        }
      end
    end
  end
end
