class Procfile
  def self.parse(content)
    content.lines.map do |line|
      next if line.blank?
      next if line.start_with?("#")

      name, command = line.split(":", 2).map(&:strip)
      [name, command]
    end.to_h
  end
end
