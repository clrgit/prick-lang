
describe "Tree" do
  using String::Text

  let(:klass) {
    Class.new do
      include Tree
      attr_reader :name

      def initialize(name, parent)
        @name = name
        Tree.initialize(self, parent)
      end

      def dump
        puts name
        indent { children.each { _1.dump } }
      end

      def sig
        empty? ? name : "#{name}(#{children.map(&:sig).join(', ')})"
      end
    end
  }

  let(:rootklass) {
    Class.new(klass) do; end
  }


  let(:subklass) {
    Class.new(klass) do; end
  }

  def make
    # root
    #   a
    #     b
    #     c
    #   d
    #     e
    #       f
    #         g
    #
    root = rootklass.new("root", nil)
    a = klass.new("a", root)
    b = klass.new("b", a)
    c = subklass.new("c", a)
    d = klass.new("d", root)
    e = subklass.new("e", d)
    f = klass.new("f", e)
    g = subklass.new("g", f)
    root
  end

  describe "#each" do
    it "iterates nodes recursively" do
      nodes = []
      make.each { |node| nodes << node.name }
      expect(nodes).to eq %w(root a b c d e f g)
    end
  end

  describe "#map" do
    it "iterates nodes recursively" do
      expect(make.map(&:name)).to eq %w(root a b c d e f g)
    end
  end

  describe "#pairs" do
    def render(pairs)
      pairs.map { |parent, child| "#{parent&.name || 'nil'},#{child.name}" }.join("\n")
    end

    def call(*klass, &expr)
      render(make.pairs(*klass, &expr))
    end

    it "emits parent/child pairs" do
      expect(call).to eq %(
        nil,root
        root,a
        a,b
        a,c
        root,d
        d,e
        e,f
        f,g
      ).align
    end

    context "when given a klass expression" do
      it "emits parent/child pairs matching the expression" do
        r = call(subklass)
        expect(r).to eq %(
          nil,c
          nil,e
          e,g
        ).align
      end
    end

    context "when given a block" do
      it "emits parent/child pairs when the block yields truish" do
        r = call { |node| %w(root a c g).include?(node.name) }
        expect(r).to eq %(
          nil,root
          root,a
          a,c
          root,g
        ).align
      end
    end
  end

  describe "#trees" do
    it "returns subtrees that satisfy the constraint" do
      expect(make.trees { %w(c d e).include? _1.name }.map(&:name)).to eq %w(c d)
    end
    it "excludes the root node" do
      expect(make.trees { %w(root c d e).include? _1.name }.map(&:name)).to eq %w(c d)
    end
    context "with a klass argument" do
      it "only considers nodes of that class" do
        expect(make.trees(subklass) { %w(a c d e).include? _1.name }.map(&:name)).to eq %w(c e)
      end
    end
  end

  describe "#nodes" do
    it "returns nodes that satisfy the constraint" do
      expect(make.nodes { %w(c d e).include? _1.name }.map(&:name)).to eq %w(c d e)
    end
    context "with a klass argument" do
      it "only considers nodes of that class" do
        expect(make.nodes(subklass) { %w(a c e g).include? _1.name }.map(&:name)).to eq %w(c e g)
      end
    end
  end

  describe "#visit" do
    it "visits nodes" do
      visited_nodes = []
      make.visit { |node| node.name == "c" and visited_nodes << node; true }
      expect(visited_nodes.map(&:name)).to eq %w(c)
    end
    context "with a klass argument" do
      it "only consider those nodes" do
        visited_nodes = []
        make.visit(subklass) { |node| visited_nodes << node; true }
        expect(visited_nodes.map(&:name)).to eq %w(c e g)
      end
    end
  end
end


