require 'rubygems'
require "#{File.dirname(__FILE__)}/config/initializers/rails_env"
%w(gems logging models).each do |initializer|
  require "#{RAILS_ROOT}/config/initializers/#{initializer}"
end

class SynchzorInterface < Object

  INTERFACE_COMMANDS = [
      "show",
      "add",
      "remove",
      "synch",
      "sync",
      "setup",
      "reset",
      "remote_clean",
      "remote_reset",
  ]

  def self.init
    @command = ARGV[0]
    if @command.nil?
      self.help
    elsif INTERFACE_COMMANDS.include?(@command)
      eval("SynchzorInterface.#{@command}")
    else
      puts "That command is not valid.  Try 'synchzor help' to learn more."
    end
  end

  def self.help
    puts <<-eos

Synchzor Help:

Commands:
  show
  add
  remove
  synch
  sync
  setup
  reset
  remote_clean
  remote_reset

show: list the folder monitored on this machine and their settings
add: add a new local folder to synch
remove: stop synching a local folder.  Content will be maintained.
synch: sync the local folder to the remote server
sync: alias for synch for you spelling purists
setup: create the local DB for storing settings (required)
reset: reset all local settings, forget all synched folders.  content will be maintained.
remote_clean: remove all files and records from the server for this synched folder
remote_reset: removes all files from the remote server, and then pushes the local copy {remote_clean + synch}

    eos
  end

  def self.show
    Synchzor.show
  end

  def self.add
    Synchzor.add
  end

  def self.remove
    Synchzor.remove
  end

  def self.synch
    Synchzor.synch
  end

  def self.sync
    self.synch
  end

  def self.setup
    ActiveRecord::Base.connection.reconnect!
    ActiveRecord::Migrator.migrate('db/migrate')
  end

  def self.reset
    Synchzor.delete_db
    ActiveRecord::Base.connection.reconnect!
    ActiveRecord::Migrator.migrate('db/migrate')
  end

  def self.remote_clean
    Synchzor.remote_clean
  end

  def self.remote_reset
    Synchzor.remote_clean
    Synchzor.synch
  end

end

################################################

SynchzorInterface.init