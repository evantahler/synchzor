class DBSetting < ActiveRecord::Base

  def self.relevant_settings
    [
        "host",
        "name",
        "password"
    ]
  end

end