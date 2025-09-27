
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions

    def file = @ast.file
    attr_reader :parser
    attr_reader :evaluator
    attr_reader :oracle
    attr_reader :ast
    attr_reader :idr

    def runtime = { CMD: "build", ENV: "prod", USER: "me" }

    def initialize(parser, oracle)
      @parser = parser
      @oracle = oracle
      @evaluator = Evaluator.new(oracle)
    end

    def eval(expr)
      trace expr
      evaluator.eval(expr)
    end

    def analyze
      trace
      @ast = parser.ast
      @idr = analyze_program(ast)
      @idr.build_tree

      analyze_unresolved
      analyze_resources

      @idr
    end

    def inspect() = "<#{self.class}>"

  private
    def analyze_resources



    end

#   def analyze_resource
#     trace
#     @idr.trees(Idr::Schema).each { |schema|
#       schema.trees(Idr::Resource).each { |resource|
#         resource.schema = schema
#       }
#     }
#   end

#   def analyze_references
#     provides = @idr.trees(Idr::Provide).map { |node| [node.uid, node] }.to_h
#     @idr.trees(Idr::Require).each { |node|
#       provides.include?(node.uid) or error node, "Unknown resource '#{node.uid}'"
#     }
#   end

    attr_reader :schema # Current schema
    attr_reader :resources # {uid=>Ast::Resource} - resource may be present/absent or not evaluated

    def analyze_program(ast)
      trace
      program = Idr::Program.new(ast)
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

    # Note: Sets @schema while processing contained nodes and resets it to nil
    # afterwards
    def analyze_schema(ast)
      trace
      constrain ast, Ast::Schema
      schema = Idr::Schema.new(ast, ast.ident.value)
      oracle.schema = schema
      schema.head = Idr::SchemaCommand.new(ast)
      schema.block = analyze_stmts(ast.block)
      oracle.schema = nil
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

    def analyze_provide(ast)
      constrain ast, Ast::Provide
      trace
      provide = Idr::Provide.new(ast, oracle.add(ast.ident))
    end

    # TODO Write to oracle
    def analyze_phase(ast)
      constrain ast, Ast::Phase
      trace
      phase = Idr::Phase.new(ast, oracle.add(ast.ident))
      phase.block = analyze_stmts(ast.block)
      phase
    end

    def analyze_require(ast)
      constrain ast, Ast::Require
      trace
      ast.references.map { |ref| Idr::Require.new(ref, oracle.ensure(ref)) }
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
            oracle.schema = schema
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
            oracle.schema = nil
          }
          break if !progress
        end
        return if !unresolved
        oracle.mark_unknown_absent
      end
    end
  end
end

