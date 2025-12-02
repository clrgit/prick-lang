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
  def command(env = {}, cmd, argv: nil, stdin: nil, stderr: nil, fail: true)
    command_wrapper(cmd, stdin: stdin, stderr: stderr, fail: fail) {
      # Add standard shell options
      bashcmd = "set -o errexit\nset -o pipefail\n#{cmd}"

      # Add arguments if present
      bashcmd = [bashcmd, *argv].join(' ') if argv

      # Clean bundler environment so that prick can be run in development mode.
      # The problem is that the bundler environment is inherited by
      # subprocesses and interferes with loading ruby commands. FIXME This is
      # only relevant when running prick in development mode
      ENV.delete_if { |k,v| %w(RUBYOPT RUBYLIB _).include?(k) || k =~ /^BUNDLER?_/ }

      # Setup environment
      env = env.map { |k,v| [k.to_s, v.to_s] }.to_h # Convert array values to strings
      env.each { |k,v| ENV[k] = v }
      Kernel.exec(ENV, bashcmd)
    }
  end

  # Like command but returns true if the command exited with the expected
  # status. Note that it suppresses standard-error by default
  #
  def command?(env = {}, cmd, expect: 0, argv: nil, stdin: nil, stderr: false)
    command(env, cmd, argv: argv, stdin: stdin, stderr: stderr, fail: false)
    @status == expect
  end

  # Exit status of the last command
  def status() @status end

  # Exception of the last command if it failed, otherwise nil TODO What is this used for?
  def exception() @exception end

  # Like #command but "execute" the ruby file by requiring it. This is only
  # possible using ruby scripts
  def script(env = {}, script, argv: nil, stdin: nil, stderr: nil, fail: true)

    # Turn script into absolute path or a path relative to the current
    # directory
    if !script.start_with?("/") && !script.start_with?(".")
      script = "./#{script}"
    end

    command_wrapper(script, stdin: stdin, stderr: stderr, fail: fail) {
      ENV.delete_if { |k,v| %w(RUBYOPT RUBYLIB _).include?(k) || k =~ /^BUNDLER?_/ }

      # Setup environment
      env = env.map { |k,v| [k.to_s, v.to_s] }.to_h # Convert array values to strings
      env.each { |k,v| ENV[k] = v }

      # Setup ARGV. Only relevant when running ruby scripts using the 'require'
      # mechanish instead of calling them through the shell
      ARGV.replace (argv || [])

      # 'Execute' script by requiring it
      require script
    }
  end

private
  # cmd is the name of the command/script and is only used in error messages
  def command_wrapper(cmd, stdin: nil, stderr: nil, fail: true, &block)
    pw = IO::pipe # pipe[0] for read, pipe[1] for write
    pr = IO::pipe
    pe = IO::pipe

    STDOUT.flush

    pid = fork {
      pw[1].close
      pr[0].close
      pe[0].close

      STDIN.reopen(pw[0])
      pw[0].close

      STDOUT.reopen(pr[1])
      pr[1].close

      STDERR.reopen(pe[1])
      pe[1].close

      yield
    }

    pw[0].close
    pr[1].close
    pe[1].close

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
    err = pe[0].readlines.map(&:chomp)

    pr[0].close
    pe[0].close

    if @status != 0
      @exception = Command::Error.new(cmd, @status, stdin, out, err)
      raise @exception if fail
    else
      @exception = nil
    end

    case stderr
      when true; [out, err]
      when false; out
      when nil
        $stderr.puts err
        out
    end
  end

  module_function :command
  module_function :command?
  module_function :script
  module_function :status
  module_function :exception
  module_function :command_wrapper
end

__END__
  class Pipe
    attr_reader :cmd
    attr_reader :status

    def writer() @pw[1] end
    def reader() @pr[0] end
    def error() @pe[0] end

    forward_to :reader, :read, :gets
    forward_to :writer, :write, :puts

    # Remaining output not consumed by #get/#read or through #reader or #error
    attr_reader :stdout
    attr_reader :stdin

    def initialize(cmd, stderr: nil, fail: true)
      @cmd = "set -o errexit\nset -o pipefail\n#{cmd}"
      @stderr = stderr
      @fail = fail

      @pw = IO::pipe # pipe[0] for read, pipe[1] for write
      @pr = IO::pipe
      @pe = IO::pipe

      STDOUT.flush

      @pid = fork {
        @pw[1].close
        @pr[0].close
        @pe[0].close

        STDIN.reopen(@pw[0])
        @pw[0].close

        STDOUT.reopen(@pr[1])
        @pr[1].close

        STDERR.reopen(@pe[1])
        @pe[1].close

        exec(cmd)
      }

      @pw[0].close
      @pr[1].close
      @pe[1].close
    end

    def wait
      @pw[1].close
      @status = Process.waitpid2(@pid)[1].exitstatus

      out = @pr[0].readlines.map(&:chomp)
      err = @pe[0].readlines.map(&:chomp)

      @pr[0].close
      @pe[0].close

      raise Command::Error.new(@cmd, @status, nil, out, err) if @status != 0 && @fail == true

      case @stderr
        when true; [out, err]
        when false; out
        when nil
          $stderr.puts err
          out
      end
    end
  end

