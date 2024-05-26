class ApplicationCommand
  include ActiveModel::Model
  include ActiveModel::Attributes

  def self.call(params = {})
    command = new(params)
    return command unless command.valid?

    command.call
    command
  end

  def success?
    errors.empty?
  end

  def failure?
    !success?
  end
end
