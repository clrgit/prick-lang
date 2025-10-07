
describe "Semver" do
  describe "#initialize" do
    it "accepts a tuple of integers" do
      expect(Semver.new(1, 2, 3).to_s).to eq "1.2.3"
    end
    it "accepts an array of integers" do
      expect(Semver.new([1, 2, 3]).to_s).to eq "1.2.3"
    end
    it "accepts a tuple of strings" do
      expect(Semver.new("1", "2", "3").to_s).to eq "1.2.3"
    end
    it "accepts a tuple of partial version strings" do
      expect(Semver.new("1.2", "3").to_s).to eq "1.2.3"
    end
    it "accepts an array of string" do
      expect(Semver.new(%w(1 2 3)).to_s).to eq "1.2.3"
    end
    it "accepts a version string" do
      expect(Semver.new("1.2.3").to_s).to eq "1.2.3"
    end
    it "rejects more than 3 elements" do
      expect { Semver.new(1, 2, 3, 4) }.to raise_error ArgumentError
    end
    it "accepts less than 3 elements" do
      expect(Semver.new(1, 2).to_s).to eq "1.2"
    end
  end

  describe "#truncate" do
    let(:v) { Semver.new(1, 2, 3) }

    it "when part == :major, sets major to zero" do
      expect(v.truncate(:major).to_s).to eq "0"
    end
    it "when part == :minor, removes the minor part" do
      expect(v.truncate(:minor).to_s).to eq "1"
    end
    it "when part == :patch, removes the patch part" do
      expect(v.truncate(:patch).to_s).to eq "1.2"
    end
  end

  describe "#extend" do
    it "when part == :major, does nothing" do
      expect(Semver.new(1).extend(:major).to_s).to eq "1"
    end
    it "when part == :minor, adds a minor part if not present" do
      expect(Semver.new(1, 2).extend(:minor).to_s).to eq "1.2"
      expect(Semver.new(1).extend(:minor).to_s).to eq "1.0"
    end
    it "when part == :patch, adds a minor part if not present" do
      expect(Semver.new(1, 2, 3).extend(:patch).to_s).to eq "1.2.3"
      expect(Semver.new(1, 2).extend(:patch).to_s).to eq "1.2.0"
    end
  end

  describe "#increment" do
    let(:v1) { Semver.new(1) }
    let(:v2) { Semver.new(1, 2) }
    let(:v3) { Semver.new(1, 2, 3) }

    context "when part == :major" do
      it "increments major" do
        expect(v1.increment(:major)).to eq "2"
      end
      it "sets minor and patch to 0 if present" do
        expect(v2.increment(:major)).to eq "2.0"
        expect(v3.increment(:major)).to eq "2.0.0"
      end
    end
    context "when part == :minor" do
      it "increments minor" do
        expect(v2.increment(:minor)).to eq "1.3"
      end
      it "sets patch to 0 if present" do
        expect(v3.increment(:minor)).to eq "1.3.0"
      end
      it "extends the version if needed" do
        expect(v1.increment(:minor)).to eq "1.1"
      end
    end
    context "when part == :minor" do
      it "increments patch" do
        expect(v3.increment(:patch)).to eq "1.2.4"
      end
      it "extends the version if needed" do
        expect(v1.increment(:patch)).to eq "1.0.1"
        expect(v2.increment(:patch)).to eq "1.2.1"
      end
    end
  end
  
  describe "#<=>" do
    let(:v1) { Semver.new(1) }
    let(:v2) { Semver.new(1, 2) }
    let(:v3) { Semver.new(1, 2, 3) }

    it "compares versions" do
      [
        "1.0.0 < 2.0.0", "1.0.0 < 1.1.0", "1.0.0 < 1.0.1",
        "1.1.0 < 2.0.0", "1.1.0 < 1.2.0", "1.1.0 < 1.1.1",
        "1.1.1 < 2.0.0", "1.1.1 < 1.2.1", "1.1.1 < 1.1.2"
      ].map { |s| 
        lhs, op, rhs = s.split(" ")
        expect(eval("Semver.new('#{lhs}') #{op} Semver.new('#{rhs}')")).to eq true
      }
    end
    it "accepts a string RHS argument" do
      expect(v1 < "2").to eq true
    end
    it "extends versions if needed" do
      expect(v1 == "1.0").to eq true
      expect(v1 < "1.1").to eq true
      expect(v2 == "1.2.0").to eq true
      expect(v2 < "1.2.1").to eq true
    end
  end

  describe "#squiggle?" do
    let(:v110) { Semver.new(1, 1, 0) }
    let(:v111) { Semver.new(1, 1, 1) }
    let(:v112) { Semver.new(1, 1, 2) }

    let(:v10) { Semver.new(1, 0) }
    let(:v11) { Semver.new(1, 1) }
    let(:v12) { Semver.new(1, 2) }

    let(:v0) { Semver.new(0) }
    let(:v1) { Semver.new(1) }
    let(:v2) { Semver.new(2) }

    it "rejects major filter" do
      expect { v2.squiggle?("1") }.to raise_error ArgumentError
    end

    it "Squiggles major.minor filter" do
      s = "1.1"
      expect(v10.squiggle?(s)).to eq false
      expect(v11.squiggle?(s)).to eq true
      expect(v110.squiggle?(s)).to eq true
      expect(v111.squiggle?(s)).to eq true
      expect(v112.squiggle?(s)).to eq true
      expect(v12.squiggle?(s)).to eq true
      expect(v2.squiggle?(s)).to eq false
    end

    it "Squiggles major.minor.patch filter" do
      s = "1.1.1"
      expect(v10.squiggle?(s)).to eq false
      expect(v11.squiggle?(s)).to eq false
      expect(v110.squiggle?(s)).to eq false
      expect(v111.squiggle?(s)).to eq true
      expect(v112.squiggle?(s)).to eq true
      expect(v12.squiggle?(s)).to eq false
      expect(v2.squiggle?(s)).to eq false
    end
  end
end

