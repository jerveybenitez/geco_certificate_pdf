module GecoCertificatePdf
  # just adds "geco_" to the table name prefix
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "geco_"
  end
end
