module Dokku
  class ApplicationRecord < ApplicationRecord
    self.abstract_class = true
    self.table_name_prefix = "dokku_"
  end
end
