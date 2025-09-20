
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
      begin
        eval_expr(expr)
      rescue StopEvaluation => ex
        @unresolved = ex.reference
        nil
      end
    end

    def eval_expr(expr)
      case expr
        when Ast::VersionMatch
          puts "TODO"
          nil
        when Ast::Value
          expr.value
        when Ast::UnExpr
          value = eval(expr.expr)
          case expr.oper
            when :EXCLAIM; !value
          else
            raise InternalError
          end
        when Ast::BinExpr
          lval = eval(expr.lexpr)
          rval = eval(expr.rexpr)
          case expr.oper
            when :OROR; lval || rval
            when :ANDAND; lval && rval
            when :LT; lval < rval
            when :LE; lval <= rval
            when :EQEQ; lval == rval
            when :NEQ; lval != rval
            when :GE; lval >= rval
            when :GT; lval > rval
          else
            raise InternalError
          end
        when Ast::RuntimeExpr
          expr.words.map(&:value).include? runtime[expr.kind]
        when Ast::ReferenceExpr
          uid = expr.ref.uid
          puts "eval_expr uid: #{uid}"

          if oracle.key?(uid)
            oracle[uid]
          else
            raise StopEvaluation.new(expr.ref)
          end
        when Ast::VersionExpr
          puts "TODO"
          nil
      else
        raise InternalError, expr.classname
      end
    end
  end
end

