
describe "Graph" do
  describe "traverse" do
    klass = Class.new do
      attr_reader :prev
      attr_reader :value

      def prevs = [prev].compact

      def initialize(prev, value)
        @prev, @value = prev, value
      end
    end

    let(:n0) { klass.new(nil, "n0") }
    let(:n1) { klass.new(n0, "n1") }
    let(:n2) { klass.new(n1, "n2") }

    context "when given a method" do
      it "traverses the nodes using the method to find the next nodes" do
        results = []
        Graph.traverse n2, :prevs do |node, traverser|
          results << ">#{node.value}"
          traverser.call
          results << "<#{node.value}"
        end
        expect(results).to eq %w(>n2 >n1 >n0 <n0 <n1 <n2)
      end
    end

    context "when not given a method" do
      it "traverses the given array" do
        results = []
        Graph.traverse n2 do |node, traverser|
          results << ">#{node.value}"
          traverser.call node.prevs
          results << "<#{node.value}"
        end
        expect(results).to eq %w(>n2 >n1 >n0 <n0 <n1 <n2)
      end
    end
  end
end

