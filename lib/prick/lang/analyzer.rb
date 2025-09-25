
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions

    def file = @ast.file
    attr_reader :parser
    attr_reader :evaluator
    attr_reader :oracle
    attr_reader :unresolved # [Idr::Unresolved]
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
      assign_uids
      @unresolved = []
      @idr = analyze_program(ast)

      while !oracle.unknown.empty?
        oracle.mark_unknown_absent

        # Find and re-compile unresolved nodes
        @idr.schemas.each { |schema|
          schema.block = schema.block.flat_map { |node|
            if node.is_a?(Idr::Unresolved)
              analyze_unresolved(node)
            else
              node
            end
          }.flatten
        }
      end

      @idr.build_tree

#     analyze_references

      @idr
    end

    def inspect() = "<#{self.class}>"

  private
    def analyze_references
      provides = @idr.trees(Idr::Provide).map { |node| [node.uid, node] }.to_h
      @idr.trees(Idr::Require).each { |node|
        provides.include?(node.uid) or error node, "Unknown resource '#{node.uid}'"
      }
    end


    def assign_uids
      ast.trees(Ast::Schema).each { |default|
        ast.nodes(Ast::Reference).each { |ref| # FIXME Turns 'require schema' into 'require current_schema.schema'
          part1, part2, rest = ref.value.split(".")
          rest.nil? or error ref, "Illegal name: '#{ref}'"
          schema = part1
          name = part2 || part1
          schema = part2 && part1 || default.ident.value
          ref.uid = "#{schema}.#{name}"
        }
      }
    end

    attr_reader :schema # Current schema
    attr_reader :resources # {uid=>Ast::Resource} - resource may be present/absent or not evaluated
    attr_reader :unresolved_stmts

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
      schema = @schema = Idr::Schema.new(ast)
      schema.head = Idr::SchemaCommand.new(ast)
      schema.block = [schema.head] + analyze_stmts(ast.block)
      @schema = nil
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
          else
            # FIXME
            ;
#           raise ArgumentError, "#{stmt.inspect}"
          end
        )
      }
      stmts
    end

    def analyze_provide(ast)
      constrain ast, Ast::Provide
      trace
      node = Idr::Provide.new(ast)
      oracle[node.uid] = true
      node
    end

    def analyze_require(ast)
      constrain ast, Ast::Require
      trace
      ast.references.map { |ref| Idr::Require.new(ref) }
    end

    # TODO Write to oracle
    def analyze_phase(ast)
      constrain ast, Ast::Phase
      trace
      phase = Idr::Phase.new(ast)
      phase.block = analyze_stmts(ast.block)
      phase
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
            node = Idr::Unresolved.new(if_, evaluator.unresolved)
            @unresolved << node
            return node
          when true
            return analyze_stmts(if_then.then_)
        end
      end
      return analyze_stmts(if_.else_) if if_.else_
      nil
    end

    def analyze_case
      trace
      nil
    end

    def analyze_unresolved(node)
      trace
      constrain node, Idr::Unresolved
      ast = node.ast
      analyze_control(ast)
    end
  end
end

