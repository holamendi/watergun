module Projects
  module Apps
    class LogsController < BaseController
      def index
      end

      def fetch
        logs = current_server.ssh_session do |ssh|
          ssh.execute("dokku logs -n 1000 #{current_app.dokku_id}")
        end

        @output = sanitize_ansi_data(logs.text_output)
      end

      ANSI_COLOR_CODE = {
        0 => "black",
        1 => "red",
        2 => "green",
        3 => "yellow",
        4 => "blue",
        5 => "purple",
        6 => "cyan",
        7 => "white"
      }

      def sanitize_ansi_data(data)
        data.gsub!(/\033\[1m/, "<b>")
        data.gsub!(/\033\[0m/, "</b></span>")

        data.gsub!(/\033\[[\d\;]{2,}m.*?<\/b><\/span>/) { |data|
          span = "<span style='"
          content = ""
          /\033\[([\d\;]{2,})m(.*?)<\/b><\/span>/.match(data) { |m|
            content = m[2]
            m[1].split(";").each do |code|
              # puts code
              if match = /(\d)(\d)/.match(code)
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
        data
      end
    end
  end
end
