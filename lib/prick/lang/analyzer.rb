
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions

    def file = @ast.file
    attr_reader :parser
    attr_reader :oracle
    attr_reader :evaluator
    attr_reader :ast
    attr_reader :idr

    def runtime = { CMD: "build", ENV: "prod", USER: "me" }

    def context = oracle.context

    def initialize(parser, oracle)
      @parser = parser
      @oracle = oracle
      @evaluator = Evaluator.new(oracle)
    end

    def analyze(oracle: true)
      trace
      build_idr
      analyze_idr
      @idr
    end

    def build_idr
      trace
      @ast = parser.ast
      @idr = build_program(ast)
      @idr
    end

    def analyze_idr
      analyze_resources
      @idr
    end

    def inspect() = "<#{self.class}>"

  private
    def build_program(ast)
      trace
      constrain ast, Ast::Program
      program = Idr::Program.new(ast)
      oracle.scope(program) { build_stmts(ast.block) }
      program
    end

    # The ast argument is only used in the error message
    def check_context(ast, *expected)
      expected.include?(oracle.context.class) or
          error ast, "#{ast.classname} can't be nested within a #{oracle.context.classname}"
    end

    # Note: Sets oracle.schema while processing contained nodes and resets it to nil
    # afterwards
    def build_schema(ast)
      trace
      constrain context, Idr::Program
      constrain ast, Ast::Schema
      check_context ast, Idr::Program
      schema = Idr::Schema.new(oracle.context, ast)
      context.schemas << schema
      oracle.add(schema)
      oracle.scope(schema) { build_stmts(ast.block) }
      []
    end

    def build_provide(ast)
      trace
      constrain ast, Ast::Provide
      check_context ast, Idr::Program, Idr::Schema, Idr::Phase
      provide = Idr::Provide.new(oracle.context, ast)
      context.block << provide
      oracle.add(provide)
      self
    end

    def build_phase(ast)
      trace
      constrain ast, Ast::Phase
      check_context ast, Idr::Program, Idr::Schema
      phase = Idr::Phase.new(oracle.context, ast)
      context.send(phase.write_attr, phase)
      oracle.add(phase)
      oracle.scope(phase) { build_stmts(ast.block) }
      []
    end

    def build_require(ast)
      trace
      constrain ast, Ast::Require
      check_context ast, Idr::Program, Idr::Schema, Idr::Phase
      context.block.concat \
          ast.references.map { |ref| Idr::RequireCommand.new(oracle.context, ref, ref.value) }
    end

    def build_command(ast)
      trace
      constrain ast, Ast::Source, Ast::ExternalCommand, Ast::CallCommand
      context.block.concat \
          case ast
            when Ast::Source; ast.files.map { |file| Idr::FileCommand.new(oracle.context, file) }
            when Ast::ExternalCommand; [Idr::ExternalCommand.new(oracle.context, ast)]
            when Ast::CallCommand; [Idr::CallCommand.new(oracle.context, ast)]
          end
    end

    def build_control(ast)
      trace
      constrain ast, Ast::Control
      case ast
        when Ast::If; build_if(ast)
        when Ast::Case; build_case(ast)
      end
    end

    def build_if(ast)
      trace
      constrain ast, Ast::If
      for if_then in ast.if_thens
        case evaluator.eval(if_then.expr)
          when nil
            Idr::Unresolved.new(oracle.context, ast, evaluator.unresolved, oracle.ensure(evaluator.unresolved))
          when true
            build_stmts(if_then.then_)
            return
        end
      end
      build_stmts(ast.else_) if ast.else_
    end

    def build_case
      trace
      raise
      []
    end

    def build_stmts(ast)
      trace
      constrain context, Idr::Resource
      constrain ast, Ast::Block
      ast.stmts.each { |stmt|
        case stmt
          when Ast::Schema; build_schema(stmt)
          when Ast::Provide; build_provide(stmt)
          when Ast::Require; build_require(stmt)
          when Ast::Phase; build_phase(stmt)
          when Ast::Command; build_command(stmt)
          when Ast::Control; build_control(stmt)
          when Ast::Function; puts "TODO: Function not implemented"
        else
          raise ArgumentError, "#{stmt.inspect}"
        end
      }
    end

    def build_unresolved
      while true
        unresolved = false
        while true
          progress = false

          # IDEA Add the index in parent.block to unresolved objects so they can
          # replace themselves in the parent. Then we can keep a short-list of
          # unresolved objects that we can process without going through all
          # other objects

          #
          # that is
#         schema.block.each.with_index { |node, i|
#
#         }

          @idr.schemas.each { |schema| # runs through all nodes several times FIXME
            schema.block = schema.block.map { |node|
              if node.is_a?(Idr::Unresolved)
                if oracle.known?(node.uid)
                  result = build_control(node.ast)
                  progress = true
                  unresolved ||= result.is_a?(Idr::Unresolved)
                  result
                else
                  unresolved = true
                  node
                end
              else
                node
              end
            }.flatten
          }
          break if !progress
        end
        return if !unresolved
        oracle.mark_unknown_absent
      end
    end

    def analyze_resources
      trace
      @idr.trees(Idr::RequireCommand) { |req|
        oracle.present?(req.uid) or error req, "Can't find resource '#{req.uid}'"
        req.node = oracle[req.uid]
      }
#     for schema in @idr.schemas
#       schema.block.each { |node|
#         if node
#     end
    end
  end
end

