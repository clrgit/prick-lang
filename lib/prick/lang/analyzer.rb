
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
      analyze_ast
      analyze_idr
      @idr
    end

    def analyze_ast
      trace
      @ast = parser.ast
      @idr = analyze_program(ast)
      @idr.build_tree
      analyze_unresolved
      @idr
    end

    def analyze_idr
      analyze_resources
      @idr
    end

    def inspect() = "<#{self.class}>"

  private
    def eval(expr)
      trace expr
      evaluator.eval(expr)
    end


    def check_containment
      @idr.trees
    end

    def analyze_program(ast)
      trace
      program = Idr::Program.new(ast, "::")
      program.schemas = []
      for stmt in ast.block.stmts
        case stmt
          when Ast::Decl
            if stmt.kind == :SCHEMA
              program.schemas << analyze_schema(stmt)
            end
        else
          error stmt, "Expected schema declaration"
        end
      end
      program
    end

    # Note: Sets oracle.schema while processing contained nodes and resets it to nil
    # afterwards
    def analyze_schema(ast)
      trace
      constrain ast, Ast::Schema
      schema = oracle.add(ast.ident) { |uid| Idr::Schema.new(ast, uid) }
      schema.head = Idr::SchemaCommand.new(ast)
      oracle.scope(schema) {
        schema.block = analyze_stmts(ast.block)
      }
      schema
    end

    def analyze_stmts(ast)
      trace
      constrain ast, Ast::Block
      stmts = []
      ast.stmts.each { |stmt|
        stmts += Array(
          case stmt
#           when Ast::Block; analyze_stmts(stmt)
            when Ast::Provide; analyze_provide(stmt)
            when Ast::Require; analyze_require(stmt)
            when Ast::Phase; analyze_phase(stmt)
            when Ast::Command; analyze_command(stmt)
            when Ast::Control; analyze_control(stmt)
            when Ast::Function; puts "TODO: Function not implemented"
          else
            raise ArgumentError, "#{stmt.inspect}"
          end
        )
      }
      stmts
    end

#   CONTAINMENTS = {
#     Program => [Phase, Function, Schema, Require, Provide],
#     Schema => [Phase, Function],
#     Phase => [],
#     Function => []
#   }



    def analyze_provide(ast)
      constrain ast, Ast::Provide
      trace
      provide = oracle.add(ast.ident) { |uid| Idr::Provide.new(ast, uid) }
    end

    def analyze_phase(ast)
      constrain ast, Ast::Phase
      trace
      phase = oracle.add(ast.ident) { |uid| Idr::Phase.new(ast, uid) }
      phase.block = analyze_stmts(ast.block)
      phase
    end

    def analyze_require(ast)
      constrain ast, Ast::Require
      trace
      ast.references.map { |ref| Idr::Require.new(ref, ref.value) }
    end

    def analyze_command(ast)
      constrain ast, Ast::Source, Ast::ExternalCommand, Ast::CallCommand
      trace
      case ast
        when Ast::Source; ast.files.map { |file| Idr::FileCommand.new(file) }
        when Ast::ExternalCommand; Idr::ExternalCommand.new(ast)
        when Ast::CallCommand; Idr::CallCommand.new(ast)
      end
    end

    def analyze_control(ast)
      constrain ast, Ast::Control
      trace
      case ast
        when Ast::If; analyze_if ast
        when Ast::Case; analyze_case ast
      end
    end

    def analyze_if(if_)
      constrain if_, Ast::If
      trace
      for if_then in if_.if_thens
        case eval(if_then.expr)
          when nil
            node = Idr::Unresolved.new(if_, evaluator.unresolved, oracle.ensure(evaluator.unresolved))
            return node
          when true
            return analyze_stmts(if_then.then_)
        end
      end
      return analyze_stmts(if_.else_) if if_.else_
      []
    end

    def analyze_case
      trace
      raise
      nil
    end

    def analyze_unresolved
      while true
        unresolved = false
        while true
          progress = false
          @idr.schemas.each { |schema|
            oracle.scope(schema) {
              schema.block = schema.block.map { |node|
                if node.is_a?(Idr::Unresolved)
                  if oracle.known?(node.uid)
                    result = analyze_control(node.ast)
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
          }
          break if !progress
        end
        return if !unresolved
        oracle.mark_unknown_absent
      end
    end

    def analyze_resources
      trace
      @idr.trees(Idr::Require) { |req|
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

