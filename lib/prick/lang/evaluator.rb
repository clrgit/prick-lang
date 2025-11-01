
module Prick::Lang
  class Evaluator < CompilerProcess
    class StopEvaluation < StopIteration
      attr_reader :reference # Ast::Reference
      def initialize(reference) @reference = reference end
    end

    attr_reader :unresolved # Ast::Reference. First unresolved reference

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

  private
    def eval_expr(expr)
      case expr
        when Ast::Reference
          uid = expr.uid = compiler.uid(expr.literal)
          if compiler.known?(uid)
            compiler.present?(uid)
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
          if Parser::OPERATORS[expr.oper][:list]
            if expr.rexpr.is_a? Ast::ListExpr
              rval = eval_expr(expr.rexpr)
            elsif expr.rspec.is_a? Ast::ParenExpr
              rval = [eval_expr(expr.rexpr.expr)]
            elsif OPERATORS[expr.oper][:value]
              rval = [eval_expr(expr.rexpr.expr)]
            end
          else
            rval = eval_expr(expr.rexpr)
          end

          constrain lval, String, Semver, true, false
          constrain rval, String, Semver, [String], [Semver], true, false

          case expr.oper
            when :OROR; lval || rval
            when :ANDAND; lval && rval
            when :LT; lval < rval
            when :LE; lval <= rval
            when :EQ; lval == rval
            when :NE; lval != rval
            when :GE; lval >= rval
            when :GT; lval > rval
            when :IN; rval.any? { |r| lval == r }
            when :PCT; rval.any? { |r| lval == r } # FIXME for now
            when :TIGT; lval.squiggle?(rval)
          else
            raise InternalError, "Unhandled binary operator: #{expr.oper.inspect}"
          end

        when Ast::ParenExpr
          eval_expr(expr.expr)

        when Ast::ListExpr
          expr.elems.map { |e| eval_expr(e) }

        # Returns true if any file was updated later than Compiler#timestamp
        when Ast::MakeExpr
          expr.paths.any? { |path|
            if File.exist?(path.path)
              File.mtime(path.path) > compiler.timestamp
            else
              warning(path, "Can't find '#{path.path}'")
              true
            end
          }

          # TODO: Add side-effect: Invalidate enclosing schema

        when Ast::Var # Must go before Ast::Value below
          # FIXME COMPILER BRACE -> compiler.variables[...]
          compiler[expr.value] or raise InternalError, "Unknown variable #{expr.value.inspect}"

        when Ast::Value
          expr.value

      else
        raise InternalError, expr.classname
      end
    end
  end
end

