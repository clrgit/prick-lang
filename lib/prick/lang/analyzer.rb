
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
      @idr = analyze_program(ast)
      @idr
    end

    def inspect() = "<#{self.class}>"

  private
    def assign_uids
      ast.trees(Ast::Schema).each { |default|
        ast.nodes(Ast::Reference).each { |ref|
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
            return Idr::Unresolved.new(prev, if_, evaluator.unresolved)
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
  end
end

__END__


#         case stmt.kind
#           when Ast::File; Idr::Command.new(s, "File: #{stmt.path}")
#           when Ast::Command; Idr::Command.new(s, "#{stmt.kind} #{stmt.source})")
#           when Ast::CallCommand
#             for ref in stmt.refs
#               Idr::Command.new(s, "Call #{ref.ref}")
#             end
#


    def resolve
      while !unresolved_stmts.empty?
        stmts = unresolved_stmts
        stmts.each { |stmt| stmt.unresolved_resource.absent! }
        unresolved_stmts = []
        stmts.each { |stmt|
          result = parse_stmt(stmt)
          if result
            Idr::ResolvedStmt.new(result)
          end
        }
      end
    end

    # Group statements into
    #
    #   commands
    #   require
    #   resources (schema/provide/function)
    #   unresolved control statements
    #   resolved control statements
    #
    # Resolvable control statements are evaluated immediately. The AST is
    # later evaluated by the generator:
    #
    #   while unresolved control statements
    #     mark referenced resources not-present
    #     compile control statements
    #   end
    #
    # Unresolved control statements are expanded into a group object that are
    # later merged into the parent group. The net result is that the schema
    # is a group of only
    #
    #   commands
    #   require
    #   provide
    #
    # where each element depends on the previous element
    #
    def analyze_stmt(s)
      puts "#analyze_stmt"; indent {
        puts s.classname
      }
    end

    def schemas(program)
      constrain program, Ast::Program
      program.trees(Ast::Schema)
    end

    def functions(schema)
      constrain schema, Ast::Schema
      schema.trees(Ast::Function)
    end

    def provides(schema)
      constrain schema, Ast::Schema
      schema.trees(Ast::Provide)
    end

    def register_resources(program)
      @resources = {}
      program.trees(Schema).each { |schema|
        @resources[schema.ident.value] = schema
        schema.nodes(Provide).each { |provide|
          uid = schema.ident.value + "." + provide.ident.value
          @resources[uid] = provide
        }
      }
#     program.trees(Schema).each { |enclosing_schema|
#       enclosing_schema.nodes(Require).each { |req|
#         req.refs.each { |ref|
#           schema, provide, rest = ref.value.split(".")
#           rest.nil? or error "Illegal reference: #{ref.value}"
#           schema ||= enclosing_schema
#           ref.uid = "#{schema}.#{provide}"
#         }
#       }
#     }
    end

    def doit(ast)
      for ast in schemas(ast)
        ident = ast.ident
        ast.block.each { |stmt|
          case stmt
            when Ast::Provide
            when Ast::Require
            when Ast::Phase
            when Ast::Command
            when Ast::Control
          else
            raise ArgumentError
          end
        }
      end
    end

  end

  class IncrementalAnalyzer
    attr_reader :prev  # Previous Idr node
    attr_reader :ast
    attr_reader :next # Next Idr node. This is used to set next's previous node
  end


end


