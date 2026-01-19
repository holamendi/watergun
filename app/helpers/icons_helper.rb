module IconsHelper
  ICONS_PATH = Rails.root.join("app/assets/icons")

  SERVICE_COLORS = {
    postgres: "text-[#336791]",
    redis: "text-[#DC382D]",
    mysql: "text-[#4479A1]",
    mariadb: "text-[#003545]",
    mongo: "text-[#47A248]",
    elasticsearch: "text-[#005571]",
    memcached: "text-[#10B981]",
    rabbitmq: "text-[#FF6600]",
    clickhouse: "text-[#FFCC00]",
    meilisearch: "text-[#FF5CAA]"
  }

  def service_icon(type, size: :md)
    size_class = icon_size_class(size)
    color_class = SERVICE_COLORS[type.to_sym] || "text-text-secondary"
    load_svg_icon("services/#{type}", class: "#{size_class} #{color_class}")
  end

  def app_icon(app, size: :md)
    if app.github_repo.present?
      github_icon(size: size)
    else
      generic_app_icon(size: size)
    end
  end

  def github_icon(size: :md)
    size_class = icon_size_class(size)
    load_svg_icon("apps/github", class: "#{size_class} text-text-secondary")
  end

  private

  def icon_size_class(size)
    case size
    when :sm then "w-3 h-3"
    when :md then "w-3.5 h-3.5"
    when :lg then "w-4 h-4"
    else "w-3.5 h-3.5"
    end
  end

  def generic_app_icon(size: :md)
    size_class = icon_size_class(size)
    load_svg_icon("apps/generic", class: "#{size_class} text-text-secondary")
  end

  def load_svg_icon(name, class: nil)
    file_path = ICONS_PATH.join("#{name}.svg")
    return nil unless File.exist?(file_path)

    svg_content = File.read(file_path)
    doc = Nokogiri::HTML::DocumentFragment.parse(svg_content)
    svg = doc.at_css("svg")
    return nil unless svg

    css_class = binding.local_variable_get(:class)
    svg["class"] = css_class if css_class
    svg.to_html.html_safe
  end
end
