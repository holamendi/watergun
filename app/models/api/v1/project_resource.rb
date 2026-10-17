class Api::V1::ProjectResource < Api::ApplicationResource
  root_key :project, :projects

  attributes :id, :name, :server_id

  attribute :created_at do |project|
    project.created_at.utc.iso8601
  end

  attribute :updated_at do |project|
    project.updated_at.utc.iso8601
  end
end
