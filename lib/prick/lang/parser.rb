
module Prick::Lang
  class Error < StandardError; end

  class Parser
    GRAMMAR_GROUPS = begin
      groups = {
        decl: [:SCHEMA, :GROUP],
        phase: [:INIT, :TERM, :META, :SEEDS, :AUTH],
        command: [:EXEC, :EVAL, :RUBY, :SQL],
        require: [:REQUIRE],
        file: [:FILE],
        punct: [:BEGIN_BLOCK, :END_BLOCK, :MULTILINE]
      }
      groups.merge! {
        unit: groups[:command] + groups[:require] + groups[:file]
      }
    end

    attr_reader :tokenizer
    forward_to :tokenizer, :compiler
    forward_to :compiler, :file

    def initialize(tokenizer)
      @tokenizer = tokenizer
    end

    def curr_node() = @curr_nodes.first
    def push_node(node) = @curr_nodes.unshift node
    def pop_node() = @curr_node.shift

    def with(node, &block)
      push_node node
      yield
      pop_node node
    end

    def parse
      ast = Ast::Program.new(nil, Token.new(file, 1, 1, "", :PROGRAM))
      with(ast) { parse_stmts }
    end

    def parse_program
      parse_commands
    end

    def parse_stmts
      while tokenizer.eof?
        parse_stmt
      end
    end

    def parse_stmt
      constrain tokenizer.bol?, true

      case tokenizer.peekkind
        when :SCHEMA, :GROUP; parse_decl
        when :OPTIONS; parse_options
        when :REQUIRE; parse_require
        when :IF; parse_if
        when :CASE; parse_case
        when :INIT, :TERM, :META, :SEEDS, :AUTH; parse_phase
        when :EXEC, :EVAL; parse_exec_eval
        when :RUBY; parse_ruby
        when :SQL; parse_sql
        when :FILE; parse_file
      else
        token = tokenizer.readtoken(:TEXT)
        error token, "Illegal kind '#{token.litt}'"
      end
    end

    def parse_schema
      token = tokenizer.readtoken
      name = parse_identifier
      decl = Ast::DeclStmt.new(curr_node, token, name)
      with(decl) { parse_block_args }
    end

    # Parse a block expression
    #
    #   { ... }
    #   FILE...
    #   COMMAND
    #
    def parse_block_args
      token = tokenizer.peektoken
      block = Ast::Block.new(curr_node, token)
      if token.kind == :BRACE_BEGIN
        tokenizer.skiptoken
        with(block) { parse_stmts }
        block.stop_token = tokenizer.readtoken(:BRACE_END)
        tokenizer.eol? or error tokenizer.readtoken, "Unexpected text after '{'"
      elsif token.kind == :FILE
        with(block) { parse_files }
      elsif token.group? :command
        with(block) { parse_command }
      else
        error token, "Expected block, command, or file"
      end
    end

    # Parse a list of files
    #
    def parse_files
      while (token = tokenizer.peektoken) && token.kind == :FILE
        Ast::FileStmt.new(curr_node, tokenizer.readtoken)
      end
      tokenizer.eol? or error token, "Expected file, got '#{token.text}'"
    end

    def parse_commands
#     while token = tokenizer.peektoken
#       case token.kind
#         when :SCHEMA, :OPTIONS; parse_global_options(token)
#         when :IF; parse_if_stmt(token)
#         when :CASE; parse_case_stmt(token)
#         when :INIT, :TERM, :META, :SEEDS, :AUTH; parse_block(token)
#         when :EXEC, :EVAL, :RUBY, :FILE
#
#
#
#       case word
#         when 'schema'
#         when 'options'
#     end
    end

    def parse_block
      expect_token '{'
      parse_stmts
      expect_token '}'
    end

    def parse_stmts
      token = get_token
      case token.kind
        when "SCHEMA"
        when "OPTIONS"
        when "IF"
        when "CASE"
        when "INIT"
        when "TERM"
        when "META" # ?
        when "SEEDS"
        when "AUTH"
        when "EXEC"
        when "EVAL"
        when "RUBY"
        when "FILE"
          case token.litt
            when /\.sql$/
            when /\.psql$/
            when /\.fox$/
            when /\.prick$/
            when /\/$/
            else
              if File.directory?(token.litt)
                raise "TODO"
                # find build file
              end
          end
      else
        parser_error(token, "Unknown token: '#{token.litt}'")
      end
    end
  end
end
