
describe "Prick::Lang" do
  describe "Token" do
    def make(text, *args) = Prick::Lang::Token.new("file.prick", 1, 1, text, *args)

    describe "::kind" do
      it "returns a kind (Symbol)" do
        expect(make("text")).to be_a Prick::Lang::Token
      end
#     context "it recognizes" do
#       def call(text) = make(text).kind
#
#       it "keywords" do
#         expect(call "if").to eq :IF
#       end
#       it "punctuation" do
#         expect(call "{").to eq :BLOCK_BEGIN
#       end
#       it "sql files" do
#         expect(call "f.sql").to eq :FILE
#       end
#       it "psql files" do
#         expect(call "f.psql").to eq :FILE
#       end
#       it "ruby files" do
#         expect(call "f.rb").to eq :FILE
#       end
#       it "fox files" do
#         expect(call "f.fox").to eq :FILE
#       end
#       it "prick files" do
#         expect(call "f.prick").to eq :FILE
#       end
#       it "text" do
#         expect(call "txt").to eq :TEXT
#         expect(call "f.txt").to eq :TEXT
#         expect(call ".f.sql").to eq :TEXT
#       end
#     end
#     context "when token is a FILE" do
#       it "sets filename" do
#         expect(make("file.sql").filename).to eq "file"
#       end
#       it "sets extname" do
#         expect(make("file.sql").extname).to eq "sql"
#       end
#     end
    end

#   describe "::args" do
#     def call(text) = Prick::Lang::Token.args(text)
#
#     it "returns [kind] when kind != :FILE" do
#       expect(call "if").to eq [:IF]
#       expect(call "something").to eq [:TEXT]
#     end
#     it "returns [kind, filename, extname] when kind == :FILE" do
#       expect(call "file.sql").to eq [:FILE, "file", "sql"]
#     end
#   end
  end
end


