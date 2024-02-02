module Apps
  class Create
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attr_reader :server, :app

    attribute :name, :string
    attribute :git_repo, :string
    attribute :git_branch, :string
    attribute :dokku_builder, :string

    def initialize(server: Current.server)
      @server = server
      @app = server.apps.new
    end
  end
end
