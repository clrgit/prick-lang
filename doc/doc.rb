DESCR = %(

  Built-in procedures
    run move.seed or seed.move ?
      Create a copy of seed tables before emptying them
    run dump.seed
      Dump seed data (not used)
    run dump.data
      Dump user data
    run dump.merge
      Dump seed & user data
    run load.data DATA-FILE
      Load seed and user data

    run auth.enable
      Enable auth
    run auth.disable
      Disable auth


  Commands
    Make command
      When a build file changes all schemas within the build file is marked
      dirty together with required resources

    Migrate command
      Migrations are defined in a make.prick file in its migration directory (eg.
      ./migration/1.2.3-1.2.4/). The prick file should define the procedures
      create_columns(), update_columns(), and delete_columns() and finalize().
      Alternatively just initial() and final() that goes before/after the merge
      step

      The build.prick file may be empty if no tables are affected by the
      migration (eg. some function changed)

      Procedure
        backup production database # If in production
        load production database # If not in production

        make-seed-for-migration:
          extract max-ids for link tables from production database
          set max-ids for key tables to 0 (their ID doesn't matter)
          create template database
          build term
          build seed using max-ids
          dump seed tables

        call add_columns

        merge:
          wipe link table records
          load seed-for-migration into merge schemas
          merge link data using copy strategy
          merge key data using any strategy

        call update_columns
        call delete_columns
        call finalize

    ./migration/1.2.3-1.2.4/
      make.prick
      create_columns.sql

      make.prick:
        procedure create_columns {
          create_columns.sql
          sql |
            alter table ...
        }

      P A table that refers to a seed record by ID
        S * It does not need to be updated if synchronized by sync or merge
          * The seed record can't be referred by ID if not synchronized by sync or merge

    Update command
      Something more clever than rebuilding the whole database

      Something like
        update tables = [ customers cases events visits users case_users ]
        For each update table
          if has-reliable-date-stamp (only acts uses this)
            Find UUIDs newer than timestamp
          else
            Find known UIDs
            Three-way diff against sagsys
          end
          if UUID is in scope
            import UUIDs
          end
        end

        update {
          timestamp TABLE TIMESTAMP-FIELD |
            filter-sql

          delta TABLE |
            filter-sql
        }

    Merge command
      The merge command consist of the following steps

          build new version with max IDs from the target database
          copy and clear seed tables
          load new production merge data (excl. meta)
          merge seed tables and maintain ID tables

      It is assumed that the migration has updated the schema of the production
      database and that links that would be broken by changes in seed data have
      been fixed beforehand

      Syntax
        schema s {
          merge {
            some-code
            copy ...
            some-code
            sync ...
            some-code
            merge ...
            some-code
            seed ...
            some-code
          }
        }

      Hierarcy of meta & seed table types
        meta
        seed
          key
            copy
            sync
            merge
          link

    Table types
      meta
          Meta tables are used to create schema objects (schemas / tables
          / functions / etc.) and are non-empty after the 'this' phase

          Meta table may not be referred to by ID except by other meta
          tables (this can be checked). They are excluded from the
          merge-backup of the production database so the backup can be
          restored without conflicts

      seed
          Seed tables are non-empty after the 'seed' phase (and not a meta
          table). Prick auto-detects seeds tables and compares it to the tables
          in the merge section to warn about unhandled tables

          Records in seed tables that use the sync or prepare strategies
          may be referenced to by ID from the rest of the target database
          (this can be checked) but it is an error if a to-be-deleted
          record is still referenced. The migration should take care of that
          before data are merged

    Table types
      Seed tables
        Regular seed tables have a unique field in addition to the primary key
        but that's not true for link tables. The categories key and link tables
        are auto-detected

      Key tables
        Key tables can be referred to by ID if it is merged using the 'sync' or
        'merge' strategies that promise to keep existing IDs constant. If not,
        the table can only be referred to by the unique key

      Link tables
        Link tables require special handling because they don't contain an
        alternate unique key. They may not be referred to at all (link tables
        never are). Link tables are generated with IDs starting at the first free
        ID in the production database

        Link table records are tracked in mumble and are deleted on merge.
        Build records are then appended to the target table

    Merge strategies
      A merge may be done on a whole table or on a subset defined by a set
      of IDs, default prick.merge_records

      copy
          Delete existing data using prick.merge_records and copy source. This
          is the fastest strategy but the table should be read-only in the
          production environment and may not be referred to by ID except from
          other copy tables

      sync
          Like copy but IDs are preserved for existing records so they can
          be referred by ID in the target database. New records get an ID
          bigger than any existing so we need max_ids

      prepare
          Like sync but register obsolete targets instead of deleting them.
          This is used when the delete operation would otherwise cascade to
          other tables, the "deleted" records should processed later

    Keywords
      copy TABLE...
          Merge tables using the copy strategy

      sync TABLE KEY [ID-TABLE]
      sync TABLE KEY '|' SQL
          Synchronize (a subset of) records using KEY as identity. ID-TABLE is a
          table of IDs (default prick.merge_records), SQL is a multiline SQL
          expression that yields an array of IDs

      prepare TABLE KEY [ID-TABLE]
      prepare TABLE KEY '|' SQL
          Like sync but obsolete records are not removed but registered in
          prick.deleted_records. The deletion process is supposed to be handled
          in the merge section's body

      handle TABLE...
          Declare a table to be a seed table. Seed record IDs are registered in
          prick.merge_records but the actual merge process is supposed to be
          done by commands in the merge section (exec, sql, etc.). Prick will
          warn about non-empty tables that are not covered by copy, sync,
          prepare, or handle

    ID tables
      Seed tables are registered in prick.merge_tables and their records in
      prick.merge_records. The ID tables are initially defined in the 'seed'
      phase and then maintained in the 'merge' phase

  Random stuff
      Procedure make-seed-for-migration
        extract max-ids for link tables from production database
        build term
        build seed with max-ids
        dump seed tables

  Syntax

    PROGRAM ::= BLOCK

    BLOCK ::= STMT+

    STMT ::=
        DECL_STMT
      | PHASE-STMT
      | OPTION_STMT
      | PROVIDE-STAT
      | REQUIRE_STMT
      | MAKE-STMT
      | IF-STMT
      | CASE-STMT
      | COMMAND-STMT
      | FILE-STMT
      | DUMP-STMT
      | LOAD-STMT
      | SNAPSHOT-STMT
      | RESTORE-STMT
      | RETURN-STMT
      | ECHO-STMT

    DECL-STMT ::=
        schema IDENT BLOCK-ARGS
      | procedure IDENT BLOCK-ARGS

    PHASE-STMT ::=
        [init | term | meta | seeds | auth | merge] BLOCK-ARGS

    OPTION_STMT ::=
      # TODO

    PROVIDE-STMT ::=
      provide IDENT

    REQUIRE-STMT ::=
      require REF+

    ECHO-STMT ::=
      echo .*

    MAKE-STMT ::=
      make PATH+
        BLOCK

    IF-STMT ::=
        if EXPR BLOCK end
      | if EXPR BLOCK else BLOCK end
      | if EXPR BLOCK ( elsif EXPR <NL> BLOCK )+ ( else BLOCK )? end

    CASE-STMT ::=
        case VAR-EXPR WHEN-STMT... [ else COMMAND... ] end

    WHEN-STMT ::=
        when ( EXPR | OPER EXPR )+ COMMAND...

    COMMAND-STMT ::=
        exec SOURCE
      | eval SOURCE
      | ruby RUBY_SCRIPT ARGUMENTS...
      | sql SOURCE
      | call REF+

    DUMP-STMT ::=
      dump BACKUP BACKUP_KINDS OBJECT_BLOCK
      load BACKUP ( schema | data )? OBJECT_BLOCK
      snapshot BACKUP OBJECT_BLOCK
      restore BACKUP OBJECT_BLOCK

    FILE-STMT ::= FILE+

    EXIT-STMT ::= return INTEGER

    BLOCK-ARGS ::=
        COMMAND-STMT
      | FILE-STMT...
      | BLOCK

    EXPR ::=
        PREFIX_OP EXPR
      | EXPR BINARY_OP EXPR
      | EXPR SUFFIX_OP
      | VARIABLE
      | LITERAL

    VARIABLE ::=
        BUILTIN_VARIABLES
      | COMMAND_VARIABLES
      | ENVIRONMENT_VARIABLES

    BUILTIN_VARIABLES ::=
        '$prj'
      | '$env'
      | '$ver'
      | '$cmd'
      | '$user'

    COMMAND_VARIABLES ::=
        '$' DOWNCASED_IDENTIFIER

    ENVIRONMENT_VARIABLES ::=
        '$' UPCASED_IDENTIFIER

    PREFIX_OP ::=
        '!'

    INFIX_OP ::=
        '&&'
      | '||'
      | '<='
      | '<'
      | '=='
      | '='
      | '!='
      | '>='
      | '>'
      | '~>'

    SUFFIX_OP ::=
        '?'

    # Files
    PATH ::= <path> '/' <*>
    FILE ::= <path> '/' <*.sql> | <*.psql> | <*.fox> | <*.prick> | <*.rb>

    # Reference & identifier
    REF ::= .? IDENT ( . IDENT )*
    IDENT ::= /[\w.]+/

    # Inline source
    SOURCE ::=
        <line>
      | '|' <indented lines>
)
