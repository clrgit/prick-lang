
# FIXME: Rename Evaluator
module Prick::Lang
  # Convert the Ast to an Idr
  class Converter < CompilerProcess
    using String::Text

    # The generated Idr
    attr_reader :idr

    def initialize
      @evaluator = Evaluator.new
      @schemas = [] # Stack of Ast::Schemas
    end

    def convert(compiler: true)
      @idr = convert_program(ast)
      convert_unresolved
      @idr
    end

    def inspect() = "<#{self.class}>"

  private
    attr_reader :evaluator

    def convert_program(ast)
      constrain ast, Ast::Program
      program = Idr::Program.new(ast)
      compiler.scope(program) { convert_stmts(ast.block) }
      compiler.add(program, Compiler::DEFAULT_TARGET)
      program
    end

    # The ast argument is only used in the error message
    def check_context(ast, *expected)
      expected.include?(compiler.context.klass) or
          error ast, "#{ast.classname} can't be nested within a #{compiler.context.classname}"
    end

    def convert_schema(ast)
      constrain compiler.context, Idr::Program, Idr::Unresolved
      constrain ast, Ast::Schema
      check_context ast, Idr::Program
      schema = Idr::Schema.new(compiler.context, ast)
      compiler.context.schemas << schema
      compiler.add(schema)
      compiler.scope(schema) { convert_stmts(ast.block) }
      []
    end

    def convert_phase(ast)
      constrain ast, Ast::Phase
      check_context ast, Idr::Program, Idr::Schema
      phase = Idr::Phase.new(compiler.context, ast)
      compiler.context.send(phase.write_attr, phase)
      compiler.add(phase)
      compiler.scope(phase) { convert_stmts(ast.block) }
      []
    end

    def convert_require(ast)
      constrain ast, Ast::Require
      check_context ast, Idr::Program, Idr::Schema, Idr::Phase
      compiler.block.concat \
          ast.references.map { |ref|
            Idr::RequireCommand.new(compiler.context, ref, ref.value)
          }
    end

    def convert_meta(ast)
      constrain ast, Ast::Meta
      check_context ast, Idr::Schema
      compiler.block.concat \
          ast.tables.map { |ref| Idr::MetaCommand.new(compiler.context, ref, ref.value) }
    end

    def convert_command(ast)
      constrain ast, Ast::FileCommand, Ast::SqlCommand, Ast::ExternalCommand, Ast::CallCommand,
                     Ast::CopyCommand, Ast::SyncCommand, Ast::PrepareCommand, Ast::HandleCommand
      compiler.block.concat \
          case ast
            when Ast::FileCommand; [Idr::FileCommand.new(compiler.context, ast.file)]
            when Ast::SqlCommand; [Idr::SqlCommand.new(compiler.context, ast)]
            when Ast::ExternalCommand; [Idr::ExternalCommand.new(compiler.context, ast)]
            when Ast::CallCommand; [Idr::CallCommand.new(compiler.context, ast)]
            when Ast::CopyCommand; [Idr::CopyCommand.new(compiler.context, ast)]
            when Ast::SyncCommand; [Idr::SyncCommand.new(compiler.context, ast)]
            when Ast::PrepareCommand; [Idr::PrepareCommand.new(compiler.context, ast)]
            when Ast::HandleCommand; [Idr::HandleCommand.new(compiler.context, ast)]
          end
    end

    def convert_provide(ast)
      constrain ast, Ast::Provide
      check_context ast, Idr::Program, Idr::Schema, Idr::Phase
      provide = Idr::ProvideCommand.new(compiler.context, ast, compiler.uid(ast.ident.value))
      compiler.block << provide
      compiler.add(provide)
    end

    def convert_control(ast)
      constrain ast, Ast::Control
      case ast
        when Ast::If; convert_if(ast)
        when Ast::Case; convert_case(ast)
        when Ast::Check; convert_check(ast)
      else
        raise InternalError
      end
    end

    def convert_if(ast)
      constrain ast, Ast::If
      for if_then in ast.if_thens
        case evaluator.eval(if_then.expr)
          when nil
            unresolved =
                Idr::Unresolved.new(
                    compiler.context, ast,
                    evaluator.unresolved, compiler.ensure(evaluator.unresolved))
            compiler.unresolved << unresolved
            compiler.block << unresolved
            return
          when true
            convert_stmts(if_then.then_)
            return
        end
      end
      convert_stmts(ast.else_) if ast.else_
    end

    def convert_check(ast)
      constrain ast, Ast::Check

      if ast.exprs.any? { |expr| evaluator.eval(expr) }
        compiler.block << Idr::CheckCommand.new(compiler.context, ast)
        convert_stmts(ast.then_)
      end
    end

    def convert_case
      raise
      []
    end

    def convert_stmts(ast)
      constrain compiler.context, Idr::Resource
      constrain ast, Ast::Block
      ast.stmts.each { |stmt|
        case stmt
          when Ast::Schema; convert_schema(stmt)
          when Ast::Provide; convert_provide(stmt)
          when Ast::Require; convert_require(stmt)
          when Ast::Meta; convert_meta(stmt)
          when Ast::Phase; convert_phase(stmt)
          when Ast::Command; convert_command(stmt)
          when Ast::SourceFile; convert_stmts(stmt.block)
          when Ast::Control; convert_control(stmt)
          when Ast::Procedure; puts "TODO: Procedure not implemented"
        else
          raise ArgumentError, "#{stmt.inspect}"
        end
      }
    end

    # Resolve unresolved references
    #
    # Resources can be defined after they have been marked 'unknown' so we need
    # an extra set of passes that resolve references to these resources. Only
    # after no more progress can be made, the remaining unresolved resources
    # are marked absent and the process start again
    #
    def convert_unresolved
      return if compiler.unresolved.empty?

      # Save unresolved nodes that are to be flattened later. New nodes are not
      # included but they will always be nested within original nodes
      original = compiler.unresolved

      while true # Last-resort loop that marks unknown resources absent
        progress = true
        while progress # Resolve later-defined resources iteratively
          unresolved = compiler.unresolved
          compiler.unresolved = []
          progress = false
          for node in unresolved
            if compiler.unknown?(node.unresolved_uid)
              compiler.unresolved << node
            else
              progress = true
              compiler.scope(node.parent, node.block) { convert_control(node.ast) }
            end
          end
        end
        break if compiler.unresolved.empty?
        compiler.mark_unknown_absent
      end

      # Flatten now-resolved nodes into parent blocks
      original.map(&:parent).uniq.each(&:flatten)
    end
  end
end

