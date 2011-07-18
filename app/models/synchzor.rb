class Synchzor < Object
  require 'net/sftp'
  require "digest"

  def self.synch
    self.start_connection
    params = self.load_params
    if params.count < 1
      puts "please provide an id= or local_folder="
      exit
    end
    sf = SynchFolder.where(params).first
    if sf.nil?
      puts "invalid input for a synched folder"
      exit
    end
    DEFAULT_LOGGER.info "Synching #{sf.local_folder} to #{sf.remote_folder} @ #{sf.host}"
    lock_file = "#{RAILS_ROOT}/tmp/lock_file.lock"
    File.open(lock_file, 'w') {|f| f.write("I am a lock file from Synchzor") }
    Net::SFTP.start(sf.host,sf.username, :password => sf.password) do |sftp|
      #check if there is a lock file on the server; exit if so
      if self.sftp_file_exists("#{sf.remote_folder}/.synchzor/", "lock_file.lock", sftp)
        DEFAULT_LOGGER.info "remote directory is locked (probably someone else is synching). exiting"
        exit
      end

        # place lockfile on server
      sftp.upload! lock_file, "#{sf.remote_folder}/.synchzor/lock_file.lock"

        # create hashes for local files, load updated_at timestamps from them
      local_files = Dir.glob("#{sf.local_folder}/*")
      files = []
      local_files.each do |f|
        l = f.dup
        l.sub!(sf.local_folder + "/","")
        l.sub!(sf.local_folder,"")
        files << {
            :full_path => f,
            :local_path => l,
            :md5 => Digest::MD5.hexdigest(File.read(f)),
            :update_time => File.mtime(f),
            :status => nil
        }
      end

        # download the remote manifest
      remote_manifest = []
      if self.sftp_file_exists("#{sf.remote_folder}/.synchzor/", "manifest", sftp)
        sftp.download "#{sf.remote_folder}/.synchzor/manifest", "#{RAILS_ROOT}/tmp/remote_manifest"
        remote_manifest = JSON.parse(File.read("#{RAILS_ROOT}/tmp/remote_manifest"))
      end

        # compare local files to manifest (files are local_new, server_new, conflict)
      files.each do |file|
        status = "local_new"
        remote_manifest.each do |m|
          if m[:needed?].nil? && m.local_path = file[:local_path] && m[:md5] != file[:md5]
            m[:needed?] = false
            if file[:update_time] > m[:update_time]
              status = "server_new"
              m[:needed?] = true
            end
            status = "conflict" if file[:update_time] <= m[:update_time]
            break
          end
        end
        file[:status] = status
      end

        # update locally new files to server
      DEFAULT_LOGGER.info " >>> Uploading locally newer files"
      files.each do |file|
        if file[:status] == "local_new"
          DEFAULT_LOGGER.info "uploading #{file[:full_path]} to #{sf.remote_folder}/#{file[:local_path]}"
          sftp.upload file[:full_path], "#{sf.remote_folder}/#{file[:local_path]}"
        end
      end

        # pull new files from server and add/overwrite

        # pull conflicting files from server and append .conflict to them

        # generate manifest and push to server
      files.each do |file|
        file[:status] = nil
      end

        # remove lockfile on server
      sftp.remove! "#{sf.remote_folder}/.synchzor/lock_file.lock"

    end
  end

  def self.show
    self.start_connection
    puts "folders being synched:"
    SynchFolder.all.each do |folder|
      str = ""
      SynchFolder.col_names_array.each do |col|
        str << "#{col}: #{folder[col]} | "
      end
      puts str
    end
  end

  def self.add
    self.start_connection
    params = self.load_params
    if params["local_folder"] && SynchFolder.where(:local_folder => params["local_folder"]).count > 0
      puts "this folder is already being tracked; exiting"
      exit
    end
    sf = SynchFolder.create(params)
    sf.save
    if sf.errors.count > 0
      sf.errors.each do |k,v|
        puts "error: #{k} => #{v}"
      end
    else
      puts "added!"
    end
  end

  def self.remove
    self.start_connection
    params = self.load_params
    if params["local_folder"]
      if SynchFolder.where(:local_folder => params["local_folder"]).count > 0
        SynchFolder.where(:local_folder => params["local_folder"]).first.delete
        puts "no longer synching #{params["local_folder"]}"
      else
        puts "local_folder is not being tracked. check with the show command"
      end
    else
      puts "local_folder is required"
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

  def self.delete_db
    DEFAULT_LOGGER.info "Starting Synchzor Reset"
    self.start_connection
    File.delete "#{RAILS_ROOT}/db/synchzor"
    DEFAULT_LOGGER.info "Old DB Deleted"
  end

  private

  def self.sftp_file_exists(path, file, sftp)
    sftp.dir.glob(path, file) do |entry|
      return true
    end
    false
  end

  def self.load_params
    params = {}
    ARGV.each do |arg|
      if arg.include?("=")
        parts = arg.split("=")
        if SynchFolder.col_names_array.include?(parts[0])
          params[parts[0]] = parts[1]
        end
      end
    end
    params
  end

  def self.start_connection
    db_config = YAML::load(File.open("#{RAILS_ROOT}/db/config.yml"))
    ActiveRecord::Base.establish_connection(db_config['synchzor'])
  end

end