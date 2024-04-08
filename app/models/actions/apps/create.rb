module Actions
  module Apps
    class Create < Action
      store_attribute :payload, :app_dokku_id, :string

      validates :app_dokku_id, presence: true

      class << self
        def processor
          Processors::Apps::Create
        end

        def enqueue!(app:)
          create!(actionable: app, app_dokku_id: app.dokku_id).enqueue
        end
      end
    end
  end
end
