require 'rubygems'
require "#{File.dirname(__FILE__)}/config/initializers/rails_env"
%w(gems logging models).each do |initializer|
  require "#{RAILS_ROOT}/config/initializers/#{initializer}"
end

task :default => 'synchzor:help'

task :environment do
  require "#{RAILS_ROOT}/app/environment"
end

begin
  require 'tasks/standalone_migrations'
rescue LoadError => e
  puts "gem install standalone_migrations to get db:migrate:* tasks! (Error: #{e})"
end

namespace :synchzor do
  desc "RUN synchzor for known folders"
  task :run => :environment do
    Synchzor.run
  end

  desc "help"
  task :help do
    puts "help will be here one day..."
  end

  desc "setup"
  task :setup do
    puts "..."
  end

  desc "test"
  task :test do
    puts "..."
  end

  desc "learn_folder"
  task :add_folder do
    puts "..."
  end

  desc "add_folder"
  task :add_folder do
    puts "..."
  end

  desc "status"
  task :status do
    puts "..."
  end

  desc "I will forget all settings and re-create the local database of folders, and the current state of your data folders will be kept"
  task :reset do
    Synchzor.delete_db
    Rake::Task["db:migrate"].execute
    DEFAULT_LOGGER.info "New DB Created"
  end

end