module Prick::Lang
  class Error < StandardError; end


  module Parser
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
