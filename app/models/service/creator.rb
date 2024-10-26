class Service::Creator
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :project
  attribute :name
  attribute :service_type
  attribute :service

  validates :project, :service_type, presence: true

  def create
    return false unless valid?

    ApplicationRecord.transaction do
      self.service = project.services.create!(service_type:, name: service_name)
      ServerActions::CreateService.run_later!(service)
    end

    true
  end

  private

  def service_name
    name.presence || default_service_name
  end

  def default_service_name
    "#{service_type}-#{SecureRandom.hex(4)}"
  end
end
