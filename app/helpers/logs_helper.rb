# credit: https://gist.github.com/pocha/5114797

module LogsHelper
  ANSI_COLOR_CODE = {
    0 => "#1e1e2e", # base
    1 => "#f38ba8", # red
    2 => "#a6e3a1", # green
    3 => "#f9e2af", # yellow
    4 => "#89b4fa", # blue
    5 => "#cba6f7", # mauve
    6 => "#89dceb", # sky
    7 => "#cdd6f4"  # text
  }

  def ansi_to_html(data)
    data.gsub!(/\033\[1m/, "<b>")
    data.gsub!(/\033\[0m/, "</b></span>")

    data.gsub!(/\033\[[\d;]{2,}m.*?<\/b><\/span>/) { |data|
      span = "<span style='"
      content = ""
      /\033\[([\d;]{2,})m(.*?)<\/b><\/span>/.match(data) { |m|
        content = m[2]
        m[1].split(";").each do |code|
          if (match = /(\d)(\d)/.match(code))
            case match[1]
            when "3"
              span += "color: #{ANSI_COLOR_CODE[match[2].to_i]}; "
            when "4"
              span += "background-color: #{ANSI_COLOR_CODE[match[2].to_i]}; "
            else
              # do nothing
            end
          else
            span += "font-weight:bold; "
          end
        end
      }
      span += "'>"
      "#{span}#{content}</b></span>"
    }
    data.html_safe
  end
end
