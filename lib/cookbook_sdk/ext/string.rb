require 'highline'

# Extend String Class
class String
  def bold
    colorize(:bold)
  end

  def gray
    colorize(:gray)
  end

  def cyan
    colorize(:cyan)
  end

  def colorize(color)
    HighLine.new.color(self, color)
  end
end
