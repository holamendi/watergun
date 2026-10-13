class Service::CreateService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :project
  attribute :name
  attribute :service_type
  attribute :service

  validates :project, :service_type, presence: true

  def save
    return false unless valid?

    ApplicationRecord.transaction do
      create_service!
      ServerAction::Enqueue.call(action: "services.create", target: service)
    end

    true
  end

  private

  def create_service!
    self.service = project.services.create!(
      server: project.server,
      service_type:,
      name: service_name
    )
  end

  def service_name
    name.presence || default_service_name
  end

  def default_service_name
    "#{service_type}-#{SecureRandom.hex(4)}"
  end
end
