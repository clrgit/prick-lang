
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
      build_unresolved
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
      expected.include?(oracle.context.klass) or
          error ast, "#{ast.classname} can't be nested within a #{oracle.context.classname}"
    end

    # Note: Sets oracle.schema while processing contained nodes and resets it to nil
    # afterwards
    def build_schema(ast)
      trace
      constrain oracle.context, Idr::Program, Idr::Unresolved
      constrain ast, Ast::Schema
      check_context ast, Idr::Program
      schema = Idr::Schema.new(oracle.context, ast)
      oracle.context.schemas << schema
      oracle.add(schema)
      oracle.scope(schema) { build_stmts(ast.block) }
      []
    end

    def build_provide(ast)
      trace
      constrain ast, Ast::Provide
      check_context ast, Idr::Program, Idr::Schema, Idr::Phase
      provide = Idr::Provide.new(oracle.context, ast)
      oracle.block << provide
      oracle.add(provide)
      self
    end

    def build_phase(ast)
      trace
      constrain ast, Ast::Phase
      check_context ast, Idr::Program, Idr::Schema
      phase = Idr::Phase.new(oracle.context, ast)
      oracle.context.send(phase.write_attr, phase)
      oracle.add(phase)
      oracle.scope(phase) { build_stmts(ast.block) }
      []
    end

    def build_require(ast)
      trace
      constrain ast, Ast::Require
      check_context ast, Idr::Program, Idr::Schema, Idr::Phase
      oracle.block.concat \
          ast.references.map { |ref|
            Idr::RequireCommand.new(oracle.context, ref, ref.value).tap { oracle.requires << _1 }
          }
    end

    def build_command(ast)
      trace
      constrain ast, Ast::FileCommand, Ast::ExternalCommand, Ast::CallCommand
      oracle.block.concat \
          case ast
#           when Ast::FileCommand; ast.files.map { |file| Idr::FileCommand.new(oracle.context, file) }
            when Ast::FileCommand; [Idr::FileCommand.new(oracle.context, ast.file)]
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
            unresolved =
                Idr::Unresolved.new(
                    oracle.context, ast,
                    evaluator.unresolved, oracle.ensure(evaluator.unresolved))
            oracle.unresolved << unresolved
            oracle.block << unresolved
            return
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
      constrain oracle.context, Idr::Resource
      constrain ast, Ast::Block
      ast.stmts.each { |stmt|
        case stmt
          when Ast::Schema; build_schema(stmt)
          when Ast::Provide; build_provide(stmt)
          when Ast::Require; build_require(stmt)
          when Ast::Phase; build_phase(stmt)
          when Ast::Command; build_command(stmt)
          when Ast::Source; build_stmts(stmt.block)
          when Ast::Control; build_control(stmt)
          when Ast::Function; puts "TODO: Function not implemented"
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
    def build_unresolved
      trace
      return if oracle.unresolved.empty?

      # Save unresolved nodes that are to be flattened later. New nodes are not
      # included but they will always be nested within original nodes
      original = oracle.unresolved

      while true # Last-resort loop that marks unknown resources absent
        progress = true
        while progress # Resolve later-defined resources iteratively
          unresolved = oracle.unresolved
          oracle.unresolved = []
          progress = false
          for node in unresolved
            if oracle.unknown?(node.unresolved_uid)
              oracle.unresolved << node
            else
              progress = true
              oracle.scope(node.parent, node.block) { build_control(node.ast) }
            end
          end
        end
        break if oracle.unresolved.empty?
        oracle.mark_unknown_absent
      end

      # Flatten now-resolved nodes into parent blocks
      original.map(&:parent).uniq.each(&:flatten)
    end

    def analyze_resources
      trace
      oracle.requires.each { |require_|
        oracle.present?(require_.uid) or error require_, "Can't find resource '#{require_.uid}'"
        require_.node = oracle.resource(require_.uid)
      }

#     for schema in @idr.schemas
#       schema.block.each { |node|
#         if node
#     end
    end
  end
end

