
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions

    def compiler = Compiler.instance
    def idr = compiler.idr

    def initialize
    end

    def analyze
      analyze_resources
      idr
    end

    def inspect() = "<#{self.class}>"

  private
    def analyze_resources
      # Link up requirements
      compiler.requires.each { |require_|
        compiler.present?(require_.uid) or error require_, "Can't find resource '#{require_.uid}'"
        require_.node = compiler.resource(require_.uid)
      }

      # Link up nodes in resource blocks. The first node has the resource
      # itself as the previous node
      idr.trees(Idr::Resource) { |resource|
        prev = resource
        resource.block.each { |node|
          node.prev = prev
          prev = node
        }
      }



      # Link up

#     for schema in @idr.schemas
#       schema.block.each { |node|
#         if node
#     end
    end
  end
end



















