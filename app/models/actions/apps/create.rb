module Actions
  module Apps
    class Create < Action
      store_attribute :payload, :dokku_id, :string

      validates :dokku_id, presence: true
    end
  end
end
