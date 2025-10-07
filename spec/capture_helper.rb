

# TODO: Library
def capture(stream = :stdout, &block) # ChatGPT
  constrain stream, :stdout, :stderr
  begin
    old = eval("$#{stream}")
    eval("$#{stream} = StringIO.new")
    yield
    eval("$#{stream}").string
  ensure
    eval("$#{stream} = old")
  end
end


