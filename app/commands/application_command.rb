class ApplicationCommand
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  def self.call(*)
    command = new(*)
    command.validate!

    command.call
  end

  def call
    raise NotImplementedError
  end

  private

  def transaction(&)
    ApplicationRecord.transaction(&)
  end
end
