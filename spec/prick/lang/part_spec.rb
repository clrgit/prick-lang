
describe "Prick::Lang" do
  describe "Whole/part model" do
    let!(:root) { Class.new(Prick::Lang::Part) }
    let!(:level1) { Class.new(root) }
    let!(:level2) { Class.new(level1) }
    let!(:array) { Class.new(root) do include Prick::Lang::Parts end }
    let!(:other) { Class.new(Prick::Lang::Part) }


    describe "Part" do
      # Can't get this to work with dynamic classes so we have to hope these
      # globally defined classes are unique
      class RSpecPart_PartKlass < Prick::Lang::Part
        attr_reader :value
        def initialize(value) @value = value end
      end

      class RSpecPart_Klass < Prick::Lang::Part
        part :a
        part :b, RSpecPart_PartKlass
      end

      describe "::root" do
        it "returns the root class in a parts hierarchy" do
          expect(level2.root).to eq root
        end
      end
      describe "::array" do
        it "returns the array class" do
          expect(root.array).to eq array
        end
        it "returns nil if undefined" do
          expect(other.array).to eq nil
        end
      end
      describe "::root?" do
        it "returns true if this is the root class" do
          expect(root.root?).to eq true
        end
        it "returns false otherwise" do
          expect(level1.root?).to eq false
        end
      end
      describe "::array?" do
        it "returns true if this is the array class" do
          expect(array.array?).to eq true
        end
        it "returns false otherwise" do
          expect(root.array?).to eq false
        end
      end

      describe "::part" do
        it "register a part object" do
          expect(RSpecPart_Klass.parts.key? :a).to eq true
        end

        it "register the class of the part object" do
          expect(RSpecPart_Klass.parts[:b]).to eq RSpecPart_PartKlass
        end

        it "creates a part object reader" do
          obj = RSpecPart_Klass.new
          expect(obj.respond_to? :a).to eq true
          expect(obj.respond_to? :b).to eq true
        end

        it "creates a part object writer" do
          obj = RSpecPart_Klass.new
          expect(obj.respond_to? :a=).to eq true
          expect(obj.respond_to? :b=).to eq true
        end
      end

      describe "<part>()" do
        it "returns the value of the part object" do
          obj = RSpecPart_Klass.new
          obj.instance_variable_set(:@b, 42)
          expect(obj.b).to eq 42
        end
      end

      describe "<part>=(value)" do
        it "sets the value of the part object" do
          obj = RSpecPart_Klass.new
          obj.b = RSpecPart_PartKlass.new(42)
          expect(obj.b.value).to eq 42
        end
      end

      context "when inherited" do
        it "defines a ::root class method" do
          expect(other.respond_to?(:root)).to eq true
        end
        it "defines a default ::array class method that returns nil" do
          expect(other.respond_to?(:array)).to eq true
          expect(other.array).to eq nil
        end
      end
    end

    describe "Parts" do
      context "when included" do
        it "redefines the #array class method on Part objects" do
          expect(root.array).not_to eq nil
        end
      end
    end
  end
end
