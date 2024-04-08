module Apps
  class Create < ApplicationCommand
    attribute :name, :string

    validates :name, presence: true

    def call
      validate!

      app = App.create!(name:)
      Actions::Apps::Create.enqueue!(app:)
    end
  end
end
