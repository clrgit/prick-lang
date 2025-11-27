
def d(*args)
  puts "\e[34m#{args.map(&:inspect).join(" ")}\e[0m"
end

def dh(*args)
  s = args.join
  if s.empty?
    h = "-" * 60
  else
    h = "- " + s + " " + "-" * (60 - (3 + s.size))
  end
  puts "\e[34m" + h + "\e[0m"
end

