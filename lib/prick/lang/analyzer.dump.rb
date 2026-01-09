module Prick::Lang
  class Analyzer
    def strflags(node, star = nil)
      (node.seed? ? "S" : (node.merge? ? "M" : (node.dirty? ? "D" : " "))) +
      (node.built? ? "B" : " ") +
      (node.excluded? ? "X" : " ") +
      (node.included? ? "I" : " ") +
      (star.nil? ? '' : (star ? '*' : ' ')) +
      " "
    end

    def strlegend = "(D - dirty, B - built, M - merge, I - included, X - excluded, * - rebuild)"

    def dumpsource(legend = strlegend)
      puts "Source Files #{legend}"; indent {
        ast.nodes(Ast::SourceFile).each { |file|
          dirty = is_dirty?(file.path) ? "D" : " "
          puts "#{dirty} #{file.path}"
        }
      }
    end

    def dumpfiles(legend = strlegend)
      files = ast.nodes(Ast::File) - ast.nodes(Ast::SourceFile).map(&:file)
      puts "Data files #{legend}"; indent {
        files.each { |file|
          dirty = is_dirty?(file.path) ? "D" : " "
          puts "#{dirty} #{file.path}"
        }
      }
    end

    def dumpnodes(legend = strlegend)
      puts "Nodes  #{legend}"; indent {
        idr.nodes.sort_by(&:serial).each { |node|
          deps = node.deps.empty? ? 'nil' : node.deps.map(&:serial).map(&:inspect).join(", ")
          reqs = node.reqs.empty? ? '' : node.reqs.map(&:serial).map(&:inspect).join(", ")
          flags = strflags(node, (compiler.mode == :build && node.build? || compiler.mode == :make && node.make?))
          printf "#{flags}%3s -> %s [%s] ", node.serial, deps, reqs
          node.dumpdep
        }
      }
    end

    def dumpresources(legend = strlegend)
      puts "Resources #{legend}"; indent {
        compiler.present.each { |uid|
          node = compiler.resources[uid]
          flags = strflags(node)
          printf flags
          puts "#{uid} -> #{node.tail.serial}"
        }
      }
    end

    def dumpschemas(legend = strlegend)
      puts "Schemas #{legend}"; indent {
        compiler.schemas.values.each { |node|
          flags = strflags(node)
          puts "#{flags}#{node.uid}"
        }
      }
    end

    def dump
      dumpsource
      dumpfiles nil
      dumpnodes nil
      dumpresources nil
      dumpschemas nil
    end
  end
end
