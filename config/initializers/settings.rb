#Read in the config YMLs
files = Dir["#{RAILS_ROOT}/config/settings/*.yml"].collect { |fn| fn.gsub("#{RAILS_ROOT}/config/settings/", "") }
files += Dir["#{RAILS_ROOT}/config/settings/environments/*.#{RAILS_ENV}.yml"].collect { |fn| fn.gsub("#{RAILS_ROOT}/config/settings/", "") }
settings_path = "#{RAILS_ROOT}/config/settings"
Setting.load(:files => files,
             :path => settings_path,
             :local => false)
