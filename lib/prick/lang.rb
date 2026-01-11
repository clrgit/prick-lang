
require_relative './ext/bash.rb'
require_relative './ext/graph.rb'
require_relative './ext/semver.rb'
require_relative './ext/tsort.rb'
require_relative './ext/tree.rb'
require_relative './ext/x_array.rb'
require_relative './ext/debug.rb' # Debug
require_relative './ext/trace.rb' # Debug

require_relative './lang/common.rb'
require_relative './lang/error.rb'
require_relative './lang/timer.rb'

require_relative './lang/token.rb'
require_relative './lang/part.rb'
require_relative './lang/ast.rb'
require_relative './lang/ast.dump.rb'
require_relative './lang/idr.rb'
require_relative './lang/idr.dump.rb'
require_relative './lang/unit.rb'
require_relative './lang/unit.dump.rb'

module Prick::Lang
  class TokenizerError < Error; end
  class EofError < Error; end # Not an error but used as a signal
end

require_relative './lang/compiler.rb'
require_relative './lang/compiler.dump.rb'
require_relative './lang/reader.rb'
require_relative './lang/tokenizer.rb'
require_relative './lang/parser.rb'
require_relative './lang/evaluator.rb'
require_relative './lang/converter.rb'
require_relative './lang/analyzer.rb'
require_relative './lang/analyzer.dump.rb'
require_relative './lang/generator.rb'
require_relative './lang/generator.dump.rb'
require_relative './lang/executer.rb'

