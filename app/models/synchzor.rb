class Synchzor < Object
  require 'net/sftp'

  def self.run
    DEFAULT_LOGGER.info "Starting Synchzor"
    self.start_connection
  end

  def self.delete_db
    DEFAULT_LOGGER.info "Starting Synchzor Reset"
    self.start_connection
    File.delete "#{RAILS_ROOT}/db/synchzor"
    DEFAULT_LOGGER.info "Old DB Deleted"
  end

  def self.update_settings
    self.start_connection
    ARGV.each do |b|
      if b.include?("=")
        parts = b.split("=")
        if DBSetting.relevant_settings.include?(parts[0])
          olds = DBSetting.where(:key => parts[0]).all
          olds.each do |old|
            old.delete
          end
          setting = DBSetting.create(:key => parts[0], :value => parts[1])
          setting.save
        else
          puts "#{parts[0]} is not needed, skipping"
        end
      end
    end
  end

  def self.show_options
    self.start_connection
    puts "needed options:"
    DBSetting.relevant_settings.each do |opt|
      puts "  #{opt}"
    end
    puts "Current Settings:"
    all_settings = DBSetting.all
    if all_settings.count > 0
      all_settings.each do |s|
        puts "  #{s.key} => #{s.value}"
      end
    end
  end

  def self.test
    self.start_connection
    self.param_load
    if self.param_check
      puts "starting connection test to #{@@host}"
      tmp_file = "#{RAILS_ROOT}/tmp/test_file.txt"
      tmp_download_file = "#{RAILS_ROOT}/tmp/test_file_downloaded.txt"
      File.open(tmp_file, 'w') {|f| f.write("I am a test file from Synchzor") }
      Net::SFTP.start(@@host,@@name, :password => @@password) do |sftp|
        puts "connected! (Name and Password ok)"
        remote_file = "#{@@path}/.tmp/test_file.txt"
        self.create_remote_dir_from_file(remote_file, sftp)
        puts "dir creation attempt OK"
        sftp.upload! tmp_file, remote_file
        puts "test file uploaded"
        sftp.download! remote_file, tmp_download_file
        puts "test file downloaded"
        sftp.remove! remote_file
        puts "remote file deleted"
      end
      File.delete(tmp_file)
      File.delete(tmp_download_file)
      puts "local test files deleted"
      puts ""
      puts "test OK!"
    end
  end

  def self.folder_details
    puts "folder details:"
    self.start_connection
    folders = SynchFolder.all
    puts "#{folders.count} folders tracked"
    folders.each do |folder|
      puts "local_folder => #{folder.local_folder}, remote_folder => #{folder.remote_folder}, last_check_timestamp => #{folder.last_check_timestamp}"
    end
  end

  def self.learn_folder
    self.start_connection
    folder = ARGV[1].dup
    if folder
      db_folder = SynchFolder.where(:local_folder => folder).first
      if db_folder
        puts "already tracking #{folder}, skipping"
      else
        sf = SynchFolder.create(:local_folder => folder)
        sf.save
        puts "#{folder} added"
      end
    else
      puts "please provide a folder"
    end
  end

  def self.forget_folder
    self.start_connection
    folder = ARGV[1].dup
    if folder
      db_folder = SynchFolder.where(:local_folder => folder).first
      if !db_folder
        puts "not tracking #{folder}"
      else
        sf = SynchFolder.where(:local_folder => folder).first
        sf.delete
        puts "#{folder} removed"
      end
    else
      puts "please provide a folder"
    end
  end

  private

  def self.param_load
    @@name = DBSetting.where(:key => "name").first.try(:value)
    @@password = DBSetting.where(:key => "password").first.try(:value)
    @@host = DBSetting.where(:key => "host").first.try(:value)
    @@path = DBSetting.where(:key => "path").first.try(:value)
  end

  def self.param_check
    if @@name.nil?
      puts "name not set"
      false
    elsif @@password.nil?
      puts "password not set"
      false
    elsif @@host.nil?
      puts "host is not set"
      false
    elsif @@path.nil?
      puts "path is not set"
      false
    else
      true
    end
  end

  def self.create_remote_dir_from_file(remote_file, sftp)
    parts = remote_file.split("/")
    parts.pop
    remote_path = parts.join("/")
    begin
      sftp.mkdir! remote_path
    rescue Net::SFTP::StatusException => e
      puts "remote folder #{remote_path} exists already"
    end
  end

  def self.start_connection
    db_config = YAML::load(File.open("#{RAILS_ROOT}/db/config.yml"))
    ActiveRecord::Base.establish_connection(db_config['synchzor'])
  end

end