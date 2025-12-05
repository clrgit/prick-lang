
module Prick
  module Database
    include Prick

    def self.settings = Prick.settings
    def self.super_conn = settings.super_conn
    def self.user_conn = settings.user_conn
    def self.conn = settings.conn



#   # Project user (owner) connection. Memoized to connect only once.
#   # TODO Rename. Also rename self.connection
#   def connection(database: nil, username: nil, environment: nil, &block)
#     if @connection.nil?
#       database ||= self.database
#       username ||= self.username
#       environment ||= self.environment
#       !database.nil? or Prick.error "Can't connect to Postgres - no database specified"
#
#       @connection = PgConn.new(database, username)
#
#       # Set database_version/environment/prick members
#       load_database_environment
#
#       # Set environment if undefined and not overridden by :environment
#       self.environment =
#           environment ||
#           Prick.state.environment ||
#           environments.key?(database_environment) && database_environment ||
#           DEFAULT_ENVIRONMENT
#     end
#     if block_given?
#       yield @connection
#     else
#       @connection
#     end
#   end
#
#   # Superuser connection. This is a connection to Postgres using the current
#   # user's credentials. It is assumed that the current user has a postgres
#   # superuser account with the same name as the user's. Memoized to connect
#   # only once
#   def self.connection(&block)
#     @@connection ||= PgConn.new("postgres")
#     if block_given?
#       yield @@connection
#     else
#       @@connection
#     end
#   end

    def self.load_build_state
      settings.build = conn.struct "select * from prick.states limit 1"
    end

    def self.save_build_state(status: nil)
      user_conn.insert "prick.builds",
          name: settings.name,
          environment: settings.environment,
          version: settings.version,
          branch: settings.branch,
          rev: settings.rev(kind: :short),
          clean: settings.clean?,
          status: status,
          prick_version: settings.prick_version,
          created_at: settings.created_at,
          compile_duration: settings.compile_duration,
          execute_duration: settings.execute_duration
    end

    #
    # R D B M S   M E T H O D S
    #
    # RDBMS methods takes a database and optionallly a user argument
    #

    def self.exist?(database)
      conn.rdbms.exist? database
    end

    def self.create(database, owner)
      # Create owner if absent
      if !super_conn.role.exist? owner
        # FIXME Should not be created as superuser but that requires that prick
        # is aware of which objects that should be created using the super user
        # and not the database owner
        super_conn.role.create owner, superuser: true, can_login: true, create_role: true
      end

      # Create database
      super_conn.rdbms.create database, owner: owner
    end

    def self.drop(database, owner = nil)
      super_conn.rdbms.drop database
      super_conn.role.drop owner if owner
    end

    #
    # D A T A B A S E   M E T H O D S
    #
    # Database methods works on the database in Settings
    #

    def self.init
      # Run prick build files. prick.sql is mandatory, other absent files are
      # ignored
      PRICK_BUILD_FILENAMES.each { |filename|
        file = File.join Prick::SCHEMA_PRICK_DIRNAME, filename
        if File.exist? file
          user_conn.exec(IO.read(file))
        elsif filename == "prick.sql"
          error "Can't find #{file}"
        end
      }
    end

    def self.status(database)
    end
  end
end





#     # Initialize prick schema
#     init_database database, username, environment
#   end

#   # Setup prick schema
#   def self.init_database(conn = user_conn, database, username, environment)
#     conn.schema.create("prick")
#     PRICK_BUILD_FILES.each { |file|
#       conn.exec(IO.read("#{SCHEMA_PRICK_DIRNAME}/#{file}"))
#     }
#
#     # Add initial build record
#     state = Prick.state # shorthand
#     conn.insert "prick.builds",
#         name: state.name,
#         version: state.version,
#         prick: state.prick_version,
#         branch: state.branch,
#         rev: state.rev(kind: :short),
#         clean: state.clean?,
#         environment: environment || Prick::DEFAULT_ENVIRONMENT,
#         built_at: nil,
#         success: nil
#   end


