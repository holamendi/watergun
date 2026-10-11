class Ssh::TextDecoder
  def initialize
    # Ruby has no UTF-8 -> UTF-8 converter. Transcoding through UTF-16 keeps
    # incomplete UTF-8 bytes between callbacks without replacing them early.
    @converter = Encoding::Converter.new("UTF-8", "UTF-16LE", invalid: :replace)
  end

  def write(data)
    @converter.convert(data).encode(Encoding::UTF_8)
  end

  def finish
    @converter.finish.encode(Encoding::UTF_8)
  end
end
