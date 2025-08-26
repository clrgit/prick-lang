
module Prick::Lang
  # Extend Token with a group function
  class Token
    def group?(group) = Parser::GRAMMAR_GROUPS[group].include?(kind)
    def groups?(groups) = Parser::GRAMMAR_GROUPS.values_at(*groups).any? { _1.include?(kind) }
  end

  class Parser
    using String::Text
    include ErrorFunctions
    class ParserError < Prick::Lang::Error; end

    GRAMMAR_GROUPS = begin
      groups = {
        decl: [:SCHEMA, :GROUP],
        phase: [:INIT, :TERM, :META, :SEEDS, :AUTH],
        command: [:EXEC, :EVAL, :RUBY, :SQL],
        require: [:REQUIRE],
        file: [:FILE],
        punct: [:BEGIN_BLOCK, :END_BLOCK, :MULTILINE]
      }
      groups.merge!({
        unit: groups[:command] + groups[:require] + groups[:file]
      })
    end

    attr_reader :tokenizer
    forward_to :tokenizer, :compiler
    forward_to :compiler, :file

    def initialize(tokenizer)
      @tokenizer = tokenizer
      @nodes = []
    end

    # Current node implemented as a stack
    def curr() = @nodes.first
    def push(node) = @nodes.unshift node
    def pop() = @nodes.shift

    # Execute block with node on top of stack. Returns node
    def with(node, &block)
      push node
      yield
      pop
    end

    def parse = parse_program

    def inspect = "<Parser: #{file}>"

    def dump
      puts self.class
      indent {
        puts "file: #{file}"
        puts "curr: #{curr.inspect}"
        if @nodes.empty?
          puts "stack: []"
        else
          puts "stack:"
          indent { @nodes.map(&:inspect) }
        end
      }
    end

  protected
    def parse_program
      ast = Ast::Program.new(file)
      with(ast) { parse_stmts }
    end

    def parse_stmts
      while tokenizer.skiplines && parse_stmt?; end
      true
    end

    def parse_stmt?
#     puts "#parse_stmt"
#     Kernel.indent {
#       puts "eof?: #{tokenizer.eof?}"
#       puts "line: #{tokenizer.line.inspect}"
#     }
      constrain tokenizer.bol?, true # FIXME doubtful
      case tokenizer.peek&.kind
        when :SCHEMA, :GROUP; parse_decl
        when :OPTIONS; parse_options
        when :REQUIRE; parse_require
        when :IF; parse_if
        when :CASE; parse_case
        when :INIT, :TERM, :META, :SEEDS, :AUTH; parse_phase
        when :EXEC, :EVAL; parse_command
        when :RUBY; parse_ruby
        when :SQL; parse_sql
        when :FILE; parse_files
      else
        return nil
      end
      true
    end

    def parse_decl
      token = tokenizer.read # eat 'schema'/'group' keywords
      ident = parse_identifier
      decl = Ast::Decl.new(curr, token, ident.text)
      with(decl) { parse_block }
    end

    def parse_phase
      token = tokenizer.read
      phase = Ast::Phase.new(curr, token)
      with(phase) { parse_block }
    end

    def parse_command
      token = tokenizer.read
      command = Ast::Command.new(curr, token, nil)
      if tokenizer.peek(:PIPE)
        tokenizer.read
        command.source = tokenizer.readblock(token.charno).text
      else
        command.source = tokenizer.readtext.text
      end
    end


    # Parse a block expression
    #
    #   { ... }
    #   FILE...
    #   COMMAND
    #
    def parse_block
      expect %w(block command file) do |token|
        block = Ast::Block.new(curr, token)
        if token.kind == :BRACE_BEGIN
          tokenizer.read # skip token
          with(block) { parse_stmts }
          block.stop_token = tokenizer.read(:BRACE_END) or expect_error "}"
        elsif token.kind == :FILE
          with(block) { parse_files }
        elsif token.group? :command
          with(block) { parse_command }
        end
      end
    end

    # Parse a list of files
    #
    def parse_files
      while !tokenizer.eof? && (token = tokenizer.peek) && token.kind == :FILE
        Ast::FileStmt.new(curr, tokenizer.read)
      end
    end

    def parse_identifier
      tokenizer.read(:IDENT) or expect_error "identifier"
    end

    #
    # E R R O R   H A N D L I N G
    #

    # English language sequence of words. Eg 'a, b, or c'
    def seq(words)
      case words.size
        when 1; words.first
        when 2; words.join(" or ")
        else words[0..-2].join(", ") + ", or " + words.last
      end
    end

    # :call-seq:
    #   expect_error(token = tokenizer.error_token || curr, *words)
    #
    def expect_error(*args)
      token = args.first.is_a?(Token) ? args.shift : (tokenizer.error_token || curr)
      words = seq Array(*args).flatten
      source = token.respond_to?(:error) && token.error || token.text
      got = (source.empty? ? "" : ", got '#{source}'")
      message = "Expected #{words}#{got}"
      error token, message
    end

    def expect(words, &block)
      token = tokenizer.peek and yield(token) or expect_error token, words
    end
  end

end

__END__

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
