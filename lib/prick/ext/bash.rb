require 'fcntl'

module Bash
  class Error < RuntimeError
    attr_reader :cmd
    attr_reader :status
    attr_reader :stdin
    attr_reader :stdout
    attr_reader :stderr

    def initialize(cmd, status, stdin, stdout, stderr)
      super(stderr.join("\n"))
      @cmd = cmd
      @status = status
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
    end
  end

  def self.command(env, cmd, **opts) = Bash::Bash.new(env).command(cmd, **opts)
  def self.command?(env, cmd, **opts) = Bash::Bash.new(env).command?(cmd, **opts)

  # Bash interface. It precompiles the environment of subprocesses
  class Bash
    # Prick environment
    attr_reader :env # { String => String }

    # Bash environment including the prick environment
    attr_reader :bash_env # { String => String }

    # Exit status of the last command
    attr_reader :status

    # Exception of the last command if it failed, otherwise nil. Command creates
    # this exception whenever a command fail but raises it only if :fail is true
    def exception() @exception end

    def initialize(env)
      # Normalize array and time
      @env = env.map { |k,v| [k.to_s, v.is_a?(Time) ? v.strftime("%F %T %Z") : v.to_s] }.to_h

      # Copy the current ENV as a hash
      @bash_env = ENV.map.to_h

      # Merge environment into bash environment
      @bash_env.merge(@env)

      # Clean bundler environment so that prick can be run in development mode.
      # The problem is that the bundler environment is inherited by
      # subprocesses and interferes with loading ruby commands. FIXME This is
      # only relevant when running prick in development mode
      @bash_env.delete_if { |k,v| %w(RUBYOPT RUBYLIB _).include?(k) || k =~ /^BUNDLER?_/ }
    end

    # Execute the shell command 'cmd' and return standard-output as an array of
    # strings. If :stdin is a string or an array of lines if will be fed to the
    # command on standard-input, if it is a IO object that IO object is piped to
    # the command
    #
    # By default #command pass through error message to stderr but if :stderr is
    # true, #command will instead return a tuple of stdout/stderr lines. If
    # :stderr is false, stderr is ignored and is the same as adding "2>/dev/null"
    # to the command
    #
    # #command raises a Command::Error exception if the command returns with an
    # exit code != 0 unless :fail is false. In that case the the exit code can be
    # fetched from Command::status
    #
    def command(cmd, argv: nil, stdin: nil, stderr: nil, fail: true)
      command_wrapper(cmd, stdin: stdin, stderr: stderr, fail: fail) {
        # Add standard shell options
        bashcmd = "set -o errexit\nset -o pipefail\n#{cmd}"

        # Add arguments if present
        bashcmd = [bashcmd, *argv].join(' ') if argv

        # Execute command using environment
        Kernel.exec(env, bashcmd)
      }
    end

    # Like command but returns true if the command exited with the expected
    # status. Note that it suppresses standard-error by default
    #
    def command?(cmd, expect: 0, argv: nil, stdin: nil, stderr: false)
      command(cmd, argv: argv, stdin: stdin, stderr: stderr, fail: false)
      @status == expect
    end

  private
    # cmd is the name of the command/script and is only used in error messages
    def command_wrapper(cmd, stdin: nil, stderr: nil, fail: true, &block)
      pw = IO::pipe # pipe[0] for read, pipe[1] for write
      pr = IO::pipe
      pe = IO::pipe if !stderr.nil?

      STDOUT.flush

      pid = fork {
        pw[1].close
        pr[0].close
        pe[0].close if !stderr.nil?

        STDIN.reopen(pw[0])
        pw[0].close

        STDOUT.reopen(pr[1])
        pr[1].close

        if !stderr.nil?
          STDERR.reopen(pe[1])
          pe[1].close
        end

        yield
      }

      pw[0].close
      pr[1].close
      pe[1].close if !stderr.nil?

      if stdin
        case stdin
          when IO; pw[1].write(stdin.read)
          when String; pw[1].write(stdin)
          when Array; pw[1].write(stdin.join("\n") + "\n")
        end
        pw[1].flush
      end
      pw[1].close # Closing standard input so the command doesn't hang on read

      @status = Process.waitpid2(pid)[1].exitstatus

      out = pr[0].readlines.map(&:chomp)
      err = stderr && pe[0].readlines.map(&:chomp)

      pr[0].close
      pe[0].close if !stderr.nil?

      if @status != 0
        @exception = Command::Error.new(cmd, @status, stdin, out, err || [])
        raise @exception if fail
      else
        @exception = nil
      end

      case stderr
        when true; [out, err]
        when false; out
        when nil; out
      end
    end
  end
end

