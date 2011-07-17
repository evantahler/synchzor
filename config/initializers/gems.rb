require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, RAILS_ENV.to_sym)

require 'active_support/dependencies'

# Bootstrap application configuration, database connections, etc
ActiveSupport::Dependencies.autoload_paths.push("#{RAILS_ROOT}/app")