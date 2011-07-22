class SynchFolder < ActiveRecord::Base
  require 'net/sftp'

  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  validates_presence_of :local_folder
  #validates_presence_of :remote_folder
  validates_presence_of :username
  validates_presence_of :host
  validates_presence_of :password

  validate :validate_local_folder
  validate :try_to_connect_and_ensure_remote_folder

  before_save :complete_entry_with_defaults

  def validate_local_folder
    if self.try(:local_folder)
      errors.add(:local_folder, "local_folder doesn't exist of cannot be accessed") if Dir[self.try(:local_folder)] == nil
    end
  end

  def try_to_connect_and_ensure_remote_folder
    if self.host && self.username && self.password && self.last_sync_timestamp.nil?
      self.remote_folder = "synchzor/#{self.local_folder.split("/").last}" if self.remote_folder.nil?
      connected = false
      Net::SFTP.start(self.host,self.username, :password => self.password) do |sftp|
        connected = true
      end
      if connected == false
        errors.add(:password, "cannot connect using these settings")
      else
        puts "ensuring #{self.remote_folder} exists on #{self.host}"
        begin
          Net::SFTP.start(self.host,self.username, :password => self.password) do |sftp|
            parts = self.remote_folder.split("/")
            composite = ""
            parts.each do |part|
              composite = composite + part + "/"
              sftp.mkdir! composite
            end
            sftp.mkdir! self.remote_folder + "/.synchzor/"
          end
        rescue Net::SFTP::StatusException => e
        end
      end
    end
  end

  def complete_entry_with_defaults
    self.port = 22 if self.port.nil?
    self.last_sync_timestamp = Time.at(0) unless self.last_sync_timestamp
  end

  def self.col_names_array
    cols = []
    SynchFolder.columns.each do |col|
      cols << col.name
    end
    cols
  end

end