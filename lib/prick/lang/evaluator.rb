
module Prick::Lang
  class Evaluator
    class StopEvaluation < StopIteration
      attr_reader :reference # Ast::Reference
      def initialize(reference) @reference = reference end
    end

    def runtime = { CMD: "build", ENV: "prod", USER: "me" }

    attr_reader :oracle
    attr_reader :unresolved # Ast::Reference. First unresolved reference

    def initialize(oracle = Oracle.new)
      @oracle = oracle
    end

    # Evaluate expr and return true/false. Return nil if the expression
    # couldn't be resolved and set #unresolved to the unevaluated resource
    # reference
    def eval(expr)
      trace
      begin
        eval_expr(expr)
      rescue StopEvaluation => ex
        @unresolved = ex.reference
        nil
      end
    end

  private
    def eval_expr(expr)
      trace
      case expr
        when Ast::Reference
          uid = expr.uid = oracle.uid(expr.literal)
          if oracle.known?(uid)
            oracle.present?(uid)
          else
            raise StopEvaluation.new(expr)
          end

        when Ast::UnaryExpr
          value = eval_expr(expr.expr)
          case expr.oper
            when :NOT; !value
            when :QUEST; value
          else
            raise InternalError, "Unhandled unary operator: #{expr.oper.inspect}"
          end

        when Ast::BinaryExpr, Ast::WhenExpr
          lval = eval_expr(expr.lexpr)
          rval = eval_expr(expr.rexpr)
          constrain lval, String, Semver, true, false
          constrain rval, String, Semver, true, false
          case expr.oper
            when :OROR; lval || rval
            when :ANDAND; lval && rval
            when :LT; lval < rval
            when :LE; lval <= rval
            when :EQ; lval == rval
            when :NE; lval != rval
            when :GE; lval >= rval
            when :GT; lval > rval
            when :IN; raise "TODO"
            when :TIGT; lval.squiggle?(rval)
          else
            raise InternalError, "Unhandled binary operator: #{expr.oper.inspect}"
          end

        when Ast::Var # Must go before Ast::Value below
          oracle[expr.value] or raise InternalError, "Unknown variable #{expr.value.inspect}"

        when Ast::Value
          expr.value

      else
        raise InternalError, expr.classname
      end
    end

#   def eval_string_expr(oper, lval, rval)
#     case oper
#     end
#   end

  end
end
















