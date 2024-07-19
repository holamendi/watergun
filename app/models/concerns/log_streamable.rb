module LogStreamable
  extend ActiveSupport::Concern

  included do
    has_many :log_streams, as: :log_streamable, dependent: :destroy
  end
end
