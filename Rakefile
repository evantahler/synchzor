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

  desc "show what folders are synching"
  task :show do
    Synchzor.show
  end

  desc "add a folder to synchzor"
  task :add  do
    Synchzor.add
  end

  desc "remove a folder to synchzor"
  task :remove  do
    Synchzor.remove
  end

  desc "sync with the server"
  task :synch  do
    Synchzor.synch
  end

  desc "sync all known folders with the server"
  task :synch_all  do
    Synchzor.synch_all
  end

  desc "remove all files and records from the server for this synched folder"
  task :remote_clean  do
    Synchzor.remote_clean
  end

  desc "removes all files from the remote server, and then pushes the local copy (used to delete files)"
  task :remote_reset  do
    Rake::Task["synchzor:remote_clean"].invoke
    Rake::Task["synchzor:synch"].invoke
  end

  desc "I will forget all settings and re-create the local database of folders, and the current state of your data folders will be kept"
  task :reset do
    Synchzor.delete_db
    ActiveRecord::Base.connection.reconnect!
    Rake::Task["db:migrate"].invoke
    DEFAULT_LOGGER.info "New DB Created"
  end

end
