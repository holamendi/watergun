module IconsHelper
  ICONS_PATH = Rails.root.join("app/assets/icons")

  # Icons with embedded brand colors (don't apply color class)
  BRAND_COLOR_ICONS = %i[postgres redis mysql].freeze

  # Fallback colors for icons using currentColor
  SERVICE_COLORS = {
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
    type_sym = type.to_sym

    if BRAND_COLOR_ICONS.include?(type_sym)
      load_svg_icon("services/#{type}", class: size_class)
    else
      color_class = SERVICE_COLORS[type_sym] || "text-text-secondary"
      load_svg_icon("services/#{type}", class: "#{size_class} #{color_class}")
    end
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
    when :sm then "w-3.5 h-3.5"
    when :md then "w-4 h-4"
    when :lg then "w-5 h-5"
    else "w-4 h-4"
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
