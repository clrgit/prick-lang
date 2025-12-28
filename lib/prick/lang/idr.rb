
module Prick::Lang
  module Idr
    # Idr nodes are either Command objects, Resource objects, or transient
    # Unresolved objects
    class Node
      include Tree
      include ClassFunctions

      # Unique integer ID. Used in debug, may be removed
      attr_reader :serial

      # Ast::Node, may be nil
      attr_reader :ast

      # Token, fails if ast is nil
      forward_to :ast, :token

      # Prick file where this node is defined
      def deffile = token.file

      # Schema (or Program) this node belongs to. Assigned by the analyzer
      attr_accessor :schema

      # True iff the node require the schema as search_path
      def require_search_path? = false

      # True iff the node is able to change the search_path. This is true for
      # SQL files, inline SQL may not change the search path but there is no
      # check for that
      def change_search_path? = false

      # True iff the node requires the current session to be committed to disk
      # before it is evaluated. This is true for external commands so they can
      # access the current state of the database using their own connection
      def require_commit_before? = false

      # True iff the node requires a commit after it has been executed. This is
      # true for mark statements (TODO: repeated mark statements should be
      # combined into one)
      def require_commit_after? = false

      # True if the node has changed since last run. Initially false but
      # #dirty! sets it to true
      def dirty? = @dirty

      # True the node is already built. Data are read from the state file and
      # may overlap with #exclude?. Initially false but #built! sets it to true
      def built? = @built

      # True if the node should be excluded from the build. Initially false but
      # #exclude! sets it to true. Excluded nodes are assumed to have already
      # been built - not nodes that should not be built at all
      def excluded? = @excluded

      # True if the node is included in target. Initially false but #include!
      # sets it to true
      def included? = @included

      # Return true if the node should be included when using 'prick build'
      def build? = included? && !excluded?

      # Return true if the node should be included when using 'prick build'
      def make? = included? && !excluded? && (dirty? || !built?)

      # Set #built? to true transitively
      def built!
        return if built?
        @built = true
        deps.each &:built!
      end

      # Set #dirty? to true transitively
      def dirty!
        return if dirty?
        @dirty = true
        reqs.each &:dirty!
      end

      # Set #exclude? to true transitively
      def exclude!()
        return if excluded?
        @excluded = true
        deps.each &:exclude!
      end

      # Set #exclude? to true transitively but ignore nodes with #exclude? ==
      # true
      def include!()
        return if included? || excluded?
        @included = true
        deps.each &:include!
      end

      # First node. Default equal to self but resources sets it to the first
      # artificial HEAD node in the block. The head node collects the node's
      # requirements, in resources it is used so we're able to insert a node
      # before all other nodes but after requirements
      def head = self

      # Last node. Default equal to self but resources sets it to the last
      # artificial TAIL node in the block. The tail node is the target of other
      # object's requirements, in resources it is used so we're able to insert
      # a node after all other nodes but before other object's requirements
      def tail = self

      # List of nodes that this node directly depends on. The list may only be
      # manipulated using #depend_on
      attr_reader :deps

      # List of nodes that requires this node directly. The list may only be
      # manipulated using #depend_on
      attr_reader :reqs

      def initialize(parent, ast)
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Node, nil
        Tree.initialize(self, parent)
        @ast = ast
        @serial = (@@SERIAL += 1)
        @deps = []
        @reqs = []
        @dirty = false
        @built = false
        @exclude = false
        @include = false

#       info
      end

      def info
        puts "#{self.classname} #{serial}"
        indent {
          puts "deps: #{deps.map(&:serial)}"
          puts "reqs: #{reqs.map(&:serial)}"
        }
      end

      # Make self depend on node
      def depend_on(node)
        self.head.deps << node.tail
        node.tail.reqs << self.head
      end

      def check_deps
        puts "#check_deps #{serial}"
#       puts "#check_deps"
#       indent {
#         self.info
#         self.deps.each(&:info)
#       puts

#       puts "a"

        deps.all? { |dep|
#         dep.reqs.include?(self)
          if !dep.reqs.include?(self)
            puts "FAILURE"
            puts
            dep.info
            false
          else
            true
          end

        } or raise "deps/reqs mismatch"

#       puts "b"
        children.each { |child| child.check_deps }
#       }
      end

      def Idr.transitive_closure(nodes, method: nil)
        constrain nodes, [Idr::Node]
        constrain method, Symbol, nil
        stack = nodes.dup
        seen = Set.new
        while node = stack.pop
          next if seen.include? node
          seen << node
          if method.nil? || node.send(method)
            if node.is_a?(Resource)
              stack.concat [node.tail]
            else
              stack.concat node.deps #if method.nil? || node.send(method)
            end
          end
#         stack.concat node.deps if method.nil? || node.send(method)
        end
        seen.to_a
      end

      def inspect = "<#{self.class}>"

    private
      @@SERIAL = 0
    end

    #
    # C O M M A N D S
    #

    class Command < Node
      # The phase this command belongs to. Initialized by the analyzer
      attr_accessor :phase
    end

    # Artificial node that creates a schema. TODO Yt
    class SchemaCommand < Command
    end

    class FileCommand < Command
      KINDS = Token::FILE_EXTS.map(&:upcase).map(&:to_sym)

      alias_method :file, :ast # Ast::File
      def kind = file.extname.upcase.to_sym
      def path = ast.value

      def require_search_path? = [:SQL, :PSQL].include?(kind)
      def change_search_path? = [:SQL, :PSQL].include?(kind)
    end

    class SqlCommand < Command
      forward_to :ast, :source, :kind
      def require_search_path? = true
    end

    class ExternalCommand < Command
      # kind can be :EVAL or :EXEC
      forward_to :ast, :source, :kind
      def path = ast.dir

      def require_search_path? = kind == :EVAL
      def change_search_path? = kind == :EVAL
      def require_commit_before? = true
    end

    class CallCommand < Command
      def procs = ast.references.map(&:uid)
      def require_search_path? = true
    end

    # Artificial node that detects meta tables (before any seed has been
    # loaded). There is ever only one of these nodes, it is added to the end of
    # the program TERM block
    class DetectMetaCommand < Command
      def initialize(parent) = super(parent, nil)
    end

    # No OPeration command. Have no function except to serve as anchors for
    # requirements and dependencies
    class NopCommand < Command
      def initialize(parent, ast = nil) = super(parent, ast)
    end

    # Abstract base class for articial nodes that marks the beginning or end of
    # a block. They serve as anchor points for requirements and dependencies
    class MarkCommand < NopCommand
      def uid = parent.uid
      def kind = raise # Either :HEAD or :TAIL
    end

    # Marks the beginning of a resource and is automatically added to
    # blocks of all resources by the analyzer
    class HeadCommand < MarkCommand
      def kind = :HEAD
    end

    # Marks the end of a resource and is automatically added to
    # blocks of all resources by the analyzer
    class TailCommand < MarkCommand
      def kind = :TAIL
      def require_commit_after? = true
    end

    class RequireCommand < NopCommand
      attr_accessor :uid # UID of required node
      attr_accessor :node # Required node
#     def node=(node)
#       depend_on(node)
#       @node = node
#     end

      def initialize(parent, ast, uid = nil)
        constrain parent, Idr::Resource
        constrain ast, Ast::Reference
        super(parent, ast)
        @uid = uid
      end
    end

    class MetaCommand < NopCommand
      attr_accessor :schema_name
      attr_accessor :table_name
      def table() = "#{schema_name}.#{table_name}"

      def initialize(parent, ast, name)
        constrain parent, Idr::Schema
        super(parent, ast)
        @table_name, @schema_name = name.split('.').reverse
        @schema_name ||= parent.ident.to_s
      end
    end

    class ProvideCommand < NopCommand
      attr_accessor :uid
      def initialize(parent, ast, uid)
        super(parent, ast)
        @uid = uid
      end
    end

    class MergeCommand < Command
      def tables = raise
    end

    class CopyCommand < MergeCommand
      forward_to :ast, :tables
    end

    class SyncCommand < MergeCommand
      forward_to :ast, :table, :key, :id_table, :source

      def tables = [table]
    end

    class PrepareCommand < MergeCommand
      forward_to :ast, :table, :key, :id_table, :source
      def tables = [table]
    end

    class HandleCommand < MergeCommand
      forward_to :ast, :tables
    end

    # A CheckCommand is only emitted when a check command was triggered. It
    # invalidates all following nodes within the resource when running 'prick
    # make'
    class CheckCommand < NopCommand
    end

    #
    # R E S O U R C E
    #

    # Can be a schema, phase, provide, or function
    #
    # A Resource may contain a block but Schemas have their blocks transferred to
    # the 'this' phase by the analyzer
    #
    class Resource < Node
      def klass = self.class
      attr_reader :ident # String
      attr_accessor :block # [Node]
      def uid = [parent&.uid, ident].compact.join(".")

      def head = block.first
      def tail = block.last
      def deps = head.deps
      def reqs = tail.reqs

      # These specializations also hits the tail node itself
      def built!() super; tail.built! end
#     def dirty!() super; tail.dirty! end
      def dirty!() super; children.map(&:dirty!) end
      def exclude!() super; tail.exclude! end
      def include!() super; tail.include! end

      def initialize(parent, ast)
        constrain parent, Resource, nil
        constrain ast, Ast::Decl, nil # Should quack #ident, nil because of Program
        super(parent, ast)
        @ident = ast&.ident&.value
        @block = []
      end

      def flatten
        @block = @block.flat_map { |node|
          if node.is_a? Unresolved
            nodes = node.flatten
            node.parent.detach(node)
            nodes
          else
            node
          end
        }
      end
    end

    # The block of a phase is assigned a HEAD and a TAIL node by the analyzer
    # that is used to anchor requirements. By having these artificial nodes we
    # can insert code after a phase's requirements but before the regular code
    # in the phase and vice-versa at the end of the block
    class Phase < Resource
      # Order is execution-order of phases: init, this, term, seed, auth, merge
      KINDS = [:INIT, :THIS] + Token::PHASES.reject { _1 == :INIT }
      ATTRS = KINDS.map(&:downcase)
      PHASES = KINDS.map { |kind| [kind, [kind.downcase, :"#{kind.downcase}="]] }.to_h

      def kind = ast.kind # Upcase Symbol
      def read_attr = kind.downcase # Reader method in parent object
      def write_attr = :"#{kind.downcase}=" # Writer method in parent object

      # Add node as first element after head
      def prepend(node) = block.insert(1, node)

      # Add node as the last element before tail. This will fail if block
      # doesn't contain at least one node (the analyzer ensures that)
      def append(node) = block.insert(-2, node)
    end

    # TODO
    # Drop/create schemas
    class SetupPhase < Phase
    end

    # TODO
    # Registers meta tables
    class MetaPhase < Phase
    end

    # Default empty phase. Added to the Idr by the analyzer for undefined phases
    class DefaultPhase < Phase
      attr_reader :kind
      def initialize(parent, kind)
        super(parent, nil)
        @kind = kind
        @ident = read_attr
      end
    end

    # The implicit 'this' phase
    class ThisPhase < Phase
      def ident = "this"
      def kind = :THIS
      def read_attr = :this
      def write_attr = :"this="
    end

    class Procedure < Resource
    end

    class Schema < Resource
      attr_reader :schema_command # Command
      attr_accessor *Phase::ATTRS # init, this, seed, term, auth, merge
      attr_reader :procedures # [Procedure]
      attr_reader :meta_commands # [MetaCommand]
      def meta_tables = meta_commands.map(&:table) # [String] Only used in dump

      # Forward #head and #tail to the this-phase
      forward_to :this, :head, :tail

      # List of schemas that this schema depends on or requires. Assigned by the analyzer
      attr_accessor :schema_deps
      attr_accessor :schema_reqs

      def exclude = schema_command.exclude

      # Get/set phase by name
      def get_phase(ident) = self.send(ident)
      def set_phase(ident, value) = self.send(:"#{ident}=", value)

      # Map from phase kind (upcase Symbol) to list of commands
      def phases = Phase::ATTRS.map { |phase| [phase.upcase, self.send(phase)] }.to_h

      # Reachable resources in schema including self
      def resources = self.nodes { |node| node.is_a? Resource } # [Resource | ProvideCommand]

      def initialize(parent, ast)
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Schema, Ast::Program
        super(parent, ast)
        @schema = self
        @this = ThisPhase.new(self, ast)
        @schema_command = self.is_a?(Program) ? NopCommand.new(self) : SchemaCommand.new(self, ast)
        @procedures = []
        @meta_commands = []
        @schema_deps = []
        @schema_reqs = []
      end

      # Programs are schemas but it is often useful to be able to exclude
      # program objects using a predicate
      def program? = false
    end

    class Program < Schema
      def key = nil
      def uid = nil
#     def uid = "public"

      attr_reader :schemas # [Schema], initialized by the analyzer

      def initialize(ast)
        super(nil, ast)
        @schemas = []
#       @meta_command = DetectMetaCommand.new(self) # FIXME Move to analyzer
      end

      def program? = true
    end

    #
    # U N R E S O L V E D
    #

    # Temporary node for unresolved conditional expressions
    class Unresolved < Resource
      forward_to :parent, :klass, :ident, :uid

      # Unresolved Ast node
      attr_reader :unresolved # Ast::Reference

      # UID of the (first) unresolved resource
      attr_reader :unresolved_uid

      def initialize(parent, ast, unresolved, unresolved_uid)
        constrain parent, Idr::Resource
        constrain ast, Ast::Control
        constrain unresolved, Ast::Reference
        constrain unresolved_uid, String
        super parent, nil
        @ast = ast
        @unresolved = unresolved
        @unresolved_uid = unresolved_uid
      end
    end
  end
end

