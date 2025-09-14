
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions
    class AnalyzerError < Prick::Lang::Error; end

    def file = @ast.file
    attr_reader :ast

    def initialize(ast)
      @ast = ast
    end

    def analyze
      puts "#analyze"; indent {
        analyze_program(ast)
      }
    end

  private
    attr_reader :schema # Current schema
    attr_reader :resources # {uid=>Resource} - resource may be present/absent or not evaluated
    attr_reader :unresolved_stmts

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

    def analyze_program(prg)
      puts "#analyze_program"; indent {
        for stmt in prg.block.stmts
          case stmt
            when Ast::Decl
              if stmt.kind == :SCHEMA
                analyze_schema(stmt)
              end
          else
            error stmt, "Expected schema declaration"
          end
        end
      }
    end





    # Group statements into
    #
    #   commands
    #   require
    #   provide
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
    def analyze_schema(s)
      puts "#analyze_schema"; indent {
        schema_name = s.ident.name
        stmts = s.block.stmts
        for stmt in s.block.stmts
          case stmt.kind
            when Ast::File; Idr::Command.new(s, "File: #{stmt.path}")
            when Ast::Command; Idr::Command.new(s, "#{stmt.kind} #{stmt.source})")
            when Ast::Call
              for ref in stmt.refs
                Idr::Command.new(s, "Call #{ref.ref}")
              end
            else
              analyze_stmt(stmt)
          end
        end
      }
    end

    def analyze_stmt(s)
      puts "#analyze_stmt"; indent {
        puts s.classname
      }
    end
  end
end


