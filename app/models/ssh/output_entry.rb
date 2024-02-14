module Ssh
  class OutputEntry
    include StoreModel::Model

    attribute :timestamp, :datetime
    attribute :stream, :string
    attribute :data, :string
  end
end
