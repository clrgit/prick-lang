
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
      # FIXME what?
      groups.merge!({
        unit: groups[:command] + groups[:require] + groups[:file]
      })
    end

    # Map from operator token kind to tuple of priority, associtivity (:left
    # or :right), and arity
    OPERATORS = {
      ANDAND: [0, :left, 2],
      OROR: [0, :left, 2],
      LT: [1, :left, 2],
      LE: [1, :left, 2],
      EQ: [1, :left, 2],
      NE: [1, :left, 2],
      GE: [1, :left, 2],
      GT: [1, :left, 2],
      EXCLAIM: [2, :right, 1],
#     TIGT: [2, :left, 2]
#     ENV: [2, :right, 1]
#     VERSION: [2, :right, 1]
    }.map { |k,v| [k, [prior: v[0], assoc: v[1], arity: v[2]] ] }

    # Operators for comparing versions
    VERSION_OPERATORS = Set[:LT, :LE, :EQ, :NE, :GE, :GT, :TIGT]

    def shunt_expr
      stack = []
      output = []
      token_args = {} # Map from list operators 'env' and 'cmd' to array of arguments

      while token = peek
        case token.kind
          when :PAREN_BEGIN; stack.push(read)
          when :PAREN_END
            read
            while op = stack.pop and op != :PAREN_BEGIN
              output << op
            end
          when :ENV, :CMD
            read
            token.value = []
            while peek?&.ident?
              token.value << read
            end
            !token.value.empty? or unexpected_token_error(peek, "identifier")
            output << token

          when :VERSION
            read
            token.value = []
            while VERSION_OPERATORS.include?(peek.kind)
              op = read
              token.value << [op, expect(:VER)]
            end
            !token.value.empty? or unexpected_token_error(peek, "version")
            output << token

          else
            if oper = OPERATORS[token]
              while top = OPERATORS[stack.last]
                break if oper[:prior] > top[:prior]
                break if oper[:prior] == top[:prior] && oper[:assoc] == :right
                output << stack.pop
              end
              stack.push token
            else
              break
            end
        end
      end

      output + stack.reverse
    end

    def parse_expr
      stack = []
      shunt_expr.each { |token|
        case token.kind
          when :VERSION
            expr = VersionExpr.new(parent, token)
            for oper, version in token.value
              compare_expr = VersionCompareExpr.new(expr, oper)
              compare_expr.version = Version.new(compare_expr, version)
              expr.exprs << compare_expr
            end
            stack.push expr
          else
            if oper = OPERATORS[token.to_s]
              case oper[:arity]
                when 1
                  e = UnExpr.new(parent, token)
                  arg = stack.pop
                  e.expr = # SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
    #             a = stack.pop
    #             stack.push([token.to_sym, a])
                when 2
                  b = stack.pop
                  a = stack.pop
                  stack.push([token.to_sym, a, b])
              else
                raise
              end
        else
          case token.kind
            when :VERSION

          stack.push(token)
        end
      }
      stack.first
    end


# i = -1
# i_end = tokens.size
# while token = tokens[i+=1]
#   puts "token:  #{token.inspect}"
#   case token
#     when :PAREN_BEGIN; stack.push(token)
#     when :PAREN_END
#       while op = stack.pop and op != :PAREN_BEGIN
#         output << op
#       end
#     when :ENV
#       while i < i_end && !OPERATORS.key?(tokens[i+1])
#         puts "EAT #{tokens[i+1]}"
#         i += 1
#       end
#       output << token
#     when :VERSION;
#     when Integer; output << token
#     when :IDENT, :OBJREF, :GRPREF, :VER; stack.push(token)
#   else
#     if oper = OPERATORS[token]
#       while top = OPERATORS[stack.last]
#         break if oper[:precedence] > top[:precedence]
#         break if oper[:precedence] == top[:precedence] && oper[:assoc] == :right
#         output << stack.pop
#         puts "  stack:  #{stack.inspect}"
#         puts "  output: #{output.inspect}"
#         puts
#       end
#       stack.push token
#
#     else
#       raise "TODO"
#     end
#   end
#
#   puts "stack:  #{stack.inspect}"
#   puts "output: #{output.inspect}"
#   puts
# end
#
# output + stack.reverse
#end


    attr_reader :tokenizer
    forward_to :tokenizer, :compiler
    forward_to :compiler, :file

    # The AST generated by #parse
    attr_reader :ast

    def initialize(tokenizer)
      @tokenizer = tokenizer
      @ast = nil
    end

    def parse = parse_program

    def inspect = "<Parser: #{file}>"

    def dump
      puts self.class
      indent { puts "file: #{file}" }
    end

  protected
    def parse_program
#     puts "#parse_program"
      @ast = Ast::Program.new(file)
      parse_stmts(@ast)
      @ast
    end

    def parse_stmts(parent)
#     puts "#parse_stmts"
      while stmt = parse_stmt(parent)
        parent.attach stmt
      end
      r
    end

    def parse_stmt(parent)
#     puts "#parse_stmt"
      case peek.kind
        when :SCHEMA, :GROUP; parse_decl parent
        when :OPTIONS; parse_options parent
        when :REQUIRE; parse_require parent
        when :IF; parse_if parent
        when :CASE; parse_case parent
        when :INIT, :TERM, :META, :SEEDS, :AUTH; parse_phase parent
        when :EXEC, :EVAL; parse_command parent
        when :RUBY; parse_ruby parent
        when :SQL; parse_sql parent
        when :FILE; parse_files parent
      else
        return nil
      end
    end

    def parse_decl(parent)
#     puts "parse_decl"
      token = read # eat schema/group keyword
      ident = expect(:IDENT)
      decl = Ast::Decl.new(parent, token, ident)
      parse_block_argument(decl)
    end

    def parse_phase(parent)
#     puts "parse_phase"
      token = read
      phase = Ast::Phase.new(parent, token)
      parse_block_argument(phase)
    end

    def parse_command(parent)
#     puts "#parse_command"
      token = read
      command = Ast::Command.new(parent, token)
      if peek.kind == :PIPE
        read
        command.source = readtext(tokenizer.indent).text
      else
        command.source = readline.text
      end
      command
    end

    def parse_if(parent)
#     puts "#parse_if"
      token = read
      command = Ast::If.new(parent, token)
      loop do
        if_then = Ast::IfThen.new(command, token, nil)
        if_then.expr = parse_expr(if_then)
        command.if_thens << if_then

        if_then.then_ = Ast::Block.new(if_then, token)
        parse_stmts(if_then.then_)

        break if peek.kind != :ELSIF
        read
      end
      if peek.kind == :ELSE
        read
        command.else_ = Ast::Block.new(command, token)
        parse_stmts command.else_
      end
      expect(:END)
    end


    # Parse a block expression
    #
    #   { ... }
    #   FILE...
    #   COMMAND
    #
    def parse_block_argument(parent)
      check %w(block command file) do |token|
        block = Ast::Block.new(parent, token)
        if token.kind == :BRACE_BEGIN
          read # skip token
          parse_stmts block
          block.stop_token = expect(:BRACE_END) or unexpected_token_error "}"
        elsif token.kind == :FILE
          parse_files block
        elsif token.group? :command
          parse_command block
        end
      end
    end

    # Parse a list of files
    #
    def parse_files(parent)
      r = nil
      while !@tokenizer.eof? && (token = peek) && token.kind == :FILE
        r = Ast::File.new(parent, read)
      end
      r
    end

    def parse_expr(parent)
#     puts "#parse_expr"
      token = readline or unexpected_token_error "expression"
      Ast::Expr.new parent, token
    end

    def parse_expr2(parent)

    end

    #
    # T O K E N I Z E R  I N T E R F A C E
    #

    # Functions from tokenizer with error handling
    # TODO: Check if **opts is actually used
    def peek(**opts) = @tokenizer.peek(**opts) or error(@tokenizer.error_token)
    def read(**opts) = @tokenizer.read(**opts) or error(@tokenizer.error_token)
    def readline(**opts) = @tokenizer.readline(**opts) or error(@tokenizer.error_token)
    def readtext(indent, **opts) = @tokenizer.readtext(indent, **opts) or error(@tokenizer.error_token)

    # Functions from tokenizer that accepts a nil return. FIXME this sacrifices
    # run-time performance for code clarity
    def peek?(**opts) = @tokenizer.peek(**opts)
    def read?(**opts) = @tokenizer.read(**opts)
    def readline?(**opts) = @tokenizer.readline(**opts)
    def readtext?(indent, **opts) = @tokenizer.readtext(indent, **opts)

    # Returns token of the given kind. Generate error if not found
    def expect(kind)
      token = tokenizer.read
      token&.kind == kind or unexpected_token_error kind
      token
    end

    #
    # E R R O R   H A N D L I N G
    #

    # :call-seq:
    #   unexpected_token_error(token = error_token || curr, *words)
    #
    # Raise an error with the message format. It does not check for an error,
    # it only displays it
    #
    #   Expected KIND, ..., or KIND, got KIND
    #
    # The error will be located at the given token (default
    # the tokenizer error token or the current object
    #
    def unexpected_token_error(*args)
      token = args.first.is_a?(Token) ? args.shift : tokenizer.error || token
      words = seq Array(*args).flatten
      source = token.respond_to?(:error) && token.error || token.text
      got = (source.empty? ? "" : ", got '#{source}'")
      message = "Expected #{words}#{got}"
      error token, message
    end

    def check(words, &block)
      token = peek and r = yield(token) or unexpected_token_error token, words
      r
    end

    #
    # U T I L I T I E S
    #

    # English language sequence of words. Eg 'a, b, or c'
    def seq(words)
      case words.size
        when 1; words.first
        when 2; words.join(" or ")
        else words[0..-2].join(", ") + ", or " + words.last
      end
    end
  end
end

