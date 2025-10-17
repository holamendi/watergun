class Enum
  def self.[](*args) = args.index_by(&:itself)
end
