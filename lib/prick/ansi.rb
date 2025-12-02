
class String
  ANSI_BOLD_START = "\e[1m"
  ANSI_BOLD_STOP = "\e[22m"
  def bold = "#{ANSI_BOLD_START}#{self.to_s}#{ANSI_BOLD_STOP}"
end
