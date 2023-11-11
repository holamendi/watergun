class Server < ApplicationRecord
  belongs_to :org

  store_attribute :data, :public_ip, :string
end
