module Actions
  module Apps
    class UpdateDeploySource < Action
      SOURCE_TYPES = %w[github].freeze

      store_attribute :payload, :dokku_id, :string
      store_attribute :payload, :source_type, :string
      store_attribute :payload, :github_repository, :string
      store_attribute :payload, :github_branch, :string

      validates :dokku_id, presence: true
      validates :source_type, inclusion: {in: SOURCE_TYPES}

      with_options if: -> { github_source? } do
        validates :github_repository, presence: true
        validates :github_branch, presence: true
      end

      def github_source?
        source_type == "github"
      end

      def self.processor
        Processors::Apps::UpdateDeploySource
      end
    end
  end
end
