require 'rubygems'
require 'bundler'
Bundler.require(:default, RAILS_ENV.to_sym)
require 'active_support/dependencies'

#Dir["#{RAILS_ROOT}/vendor/gems/*"].each do |gem|
#  puts "gem: #{gem}"
#  Dir["#{gem}/lib/*.rb"].each do |init_file|
#    puts "using:#{init_file}"
#    require init_file
#  end
#end
#
#require "#{RAILS_ROOT}/vendor/gems/net-ssh-2.1.4/lib/net/ssh.rb"
#require "#{RAILS_ROOT}/vendor/gems/net-sftp-2.0.5/lib/net/sftp.rb"

#Dir["#{RAILS_ROOT}/vendor/source/*.rb"].each do |gem|
#  puts gem
#  require gem
#end

# Bootstrap application configuration, database connections, etc
ActiveSupport::Dependencies.autoload_paths.push("#{RAILS_ROOT}/app")