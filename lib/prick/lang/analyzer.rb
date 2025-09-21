
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

    def initialize(parser)
      @parser = parser
      @oracle = Oracle.new
      @evaluator = Evaluator.new(oracle)
    end

    def eval(expr)
      evaluator.eval(expr)
    end

    def analyze
      trace
      @ast = parser.ast
      assign_uids
      @unresolved = []
      @idr = analyze_program(ast)

#     while !@unresolved.empty?
#       for node in unresolved
#         oracle[node.uid] = false
#       end
#       for node in
#       idr = analyze_unresolved
#
#     puts
#     puts "Unresolved"
#     indent { puts unresolved.map { |node| node.unresolved.uid } }

      @idr
    end

    def inspect() = "<#{self.class}>"

  private
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
      program = Idr::Program.new(nil, ast)
      program.schemas = []
      for stmt in ast.block.stmts
        case stmt
          when Ast::Decl
            if stmt.kind == :SCHEMA
              program.schemas << analyze_schema(program, stmt)
            end
        else
          error stmt, "Expected schema declaration"
        end
      end
      program
    end

    def analyze_schema(prev, ast)
      trace
      constrain ast, Ast::Schema
      schema = @schema = Idr::Schema.new(prev, ast)
      schema.head = Idr::SchemaCommand.new(prev, ast)
      schema.nodes = [schema.head] + analyze_stmts(schema.head, ast.block)
      @schema = nil
      schema
    end

    def analyze_stmts(prev, ast)
      trace
      constrain ast, Ast::Block
      stmts = []
      ast.stmts.each { |stmt|
        stmts += Array(
          case stmt
#           when Ast::Block; analyze_stmts(prev, stmt)
            when Ast::Provide; analyze_provide(prev, stmt)
            when Ast::Require; analyze_require(prev, stmt)
            when Ast::Phase; analyze_phase(prev, stmt)
            when Ast::Command; analyze_command(prev, stmt)
            when Ast::Control; analyze_control(prev, stmt)
          else
            # FIXME
            ;
#           raise ArgumentError, "#{stmt.inspect}"
          end
        )
        prev = stmts.last
      }
      stmts
    end

    def analyze_provide(prev, ast)
      constrain ast, Ast::Provide
      trace
      node = Idr::Provide.new(prev, ast)
      oracle[node.uid] = true
      node
    end

    def analyze_require(prev, ast)
      constrain ast, Ast::Require
      trace
      ast.references.map { |ref| Idr::Require.new(prev, ref) }
    end

    # TODO Write to oracle
    def analyze_phase(prev, ast)
      constrain ast, Ast::Phase
      trace
      phase = Idr::Phase.new(schema.head, ast)
      phase.nodes = analyze_stmts(phase, ast.block)
      phase
    end

    def analyze_command(prev, ast)
      constrain ast, Ast::Source, Ast::ExternalCommand, Ast::CallCommand
      trace
      case ast
        when Ast::Source; ast.files.map { |file| prev = Idr::FileCommand.new(prev, file) }
        when Ast::ExternalCommand; Idr::ExternalCommand.new(prev, ast)
        when Ast::CallCommand; Idr::CallCommand.new(prev, ast)
      end
    end

    def analyze_control(prev, ast)
      constrain ast, Ast::Control
      trace
      case ast
        when Ast::If; analyze_if prev, ast
        when Ast::Case; analyze_case prev, ast
      end
    end

    def analyze_if(prev, if_)
      constrain if_, Ast::If
      trace
      for if_then in if_.if_thens
        case eval(if_then.expr)
          when nil
            node = Idr::Unresolved.new(prev, if_, evaluator.unresolved)
            @unresolved << node
            return node
          when true
            return analyze_stmts(prev, if_then.then_)
        end
      end
      return analyze_stmts(prev, if_.else_) if if_.else_
      nil
    end

    def analyze_case
      trace
      nil
    end

    def analyze_unresolved(node)
      prev = node.prev
      ast = node.ast
      # next? FIXME
    end
  end
end

