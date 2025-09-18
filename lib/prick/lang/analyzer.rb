__END__
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions

    def file = @ast.file
    attr_reader :parser
    attr_reader :ast

    def initialize(parser)
      @parser = parser
    end

    def analyze
      @ast = parser.ast
      puts "#analyze"; indent {
      analyze_program(ast)
      }
    end

  private
#   def assign_uids
#     ast.nodes(Ast::Provide, Ast::Require, Ast::Resource
#   end


    attr_reader :schema # Current schema
    attr_reader :resources # {uid=>Ast::Resource} - resource may be present/absent or not evaluated
    attr_reader :unresolved_stmts

    def analyze_program(ast)
      puts "#analyze_program"; indent {
        program = Idr::Program.new(nil, ast)
        for stmt in ast.block.stmts
          case stmt
            when Ast::Decl
              if stmt.kind == :SCHEMA
                analyze_schema(program, stmt)
              end
          else
            error stmt, "Expected schema declaration"
          end
        end
      }
    end

    def analyze_schema(program, ast)
      constrain ast, Ast::Schema
      puts "#analyze_schema"; indent {
      @schema = Schema.new(program, ast)
      schema_name = s.ident.value
      ident = ast.ident
      schema.body = analyze_stmts(schema.head, ast)
      @schema = nil
      }
    end

    def analyze_stmts(prev, ast)
      puts "#analyze_stmts"; indent {
      constrain ast, Ast::Block
      stmts = []
      ast.block.each { |stmt|
        stmts <<
          case stmt
            when Ast::Provide; analyze_provide(prev, stmt)
            when Ast::Require; analyze_require(prev, stmt)
            when Ast::Phase; analyze_phase(prev, stmt)
            when Ast::Command; analyze_command(prev, stmt)
            when Ast::Control; analyze_control(prev, stmt)
          else
            raise ArgumentError
          end
        prev = stmts.last
      }
      }
      stmts
    end

    def analyze_provide(prev, ast)
      puts "#analyze_provide"
      provide = Idr::Provide.new(prev, ast, )
#     provide.head = provide.body =

    end


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


