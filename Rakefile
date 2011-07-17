require 'rubygems'
require "#{File.dirname(__FILE__)}/config/initializers/rails_env"
%w(gems logging).each do |initializer|
  require "#{RAILS_ROOT}/config/initializers/#{initializer}"
end

task :default => 'synchzor:help'

task :environment do
  require "#{RAILS_ROOT}/app/environment"
end

namespace :synchzor do
  desc "RUN synchzor for known folders"
  task :run => :environment do
    require "#{RAILS_ROOT}/app/main"
    run
  end

  desc "help"
  task :help do
    puts "help will be here one day..."
  end

end
