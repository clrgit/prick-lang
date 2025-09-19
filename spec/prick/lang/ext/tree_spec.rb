
describe "Tree" do
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

  let(:subklass) {
    Class.new(klass) do
    end
  }

  def make
    root = klass.new("root", nil)
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

  describe "#trees" do
    it "returns subtrees that satisfy the constraint" do
      expect(make.trees { %w(c d e).include? _1.name }.map(&:name)).to eq %w(c d)
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
