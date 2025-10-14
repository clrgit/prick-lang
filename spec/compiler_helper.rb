

def make_compiler
  variables = { cmd: "build", env: "prod", user: "me", ver: Semver.new("1.2.3") }
  Prick::Lang::Compiler.new(variables: variables)
end


