class Synchzor < Object
  require 'net/sftp'
  require "digest"

  DB_FILE = "db/synchzor"

  def self.synch(params = nil)

    self.load_db
    params = self.load_params
    found = false
    sf = {}
    new_db = []
    @DB.each do |sf_|
      if params["local_folder"] == sf_["local_folder"]
        found = true
        sf = sf_.dup
      else
        new_db << sf_
      end
    end
    unless found
      puts "this local_folder is not found, and not not being synched"
      exit
    end

    DEFAULT_LOGGER.info "Synching #{sf['local_folder']} to #{sf['remote_folder']} @ #{sf['host']}"

    lock_file = "#{RAILS_ROOT}/tmp/lock_file.lock"
    local_manifest_file = "#{RAILS_ROOT}/tmp/local_manifest.json"
    remote_manifest_file = "#{RAILS_ROOT}/tmp/remote_manifest.json"
    server_manifest_file = "#{sf['remote_folder']}/.synchzor/manifest.json"
    remote_deleted_file = "#{RAILS_ROOT}/tmp/removed_files.json"
    server_deleted_file = "#{sf['remote_folder']}/.synchzor/removed_files.json"

    File.open(lock_file, 'w') {|f| f.write("I am a lock file from Synchzor") }
    Net::SFTP.start(sf['host'],sf['username'], :password => sf['password']) do |sftp|
      #check if there is a lock file on the server; exit if so
      if self.sftp_file_exists("#{sf['remote_folder']}/.synchzor/", "lock_file.lock", sftp)
        DEFAULT_LOGGER.info "remote directory is locked (probably someone else is synching). exiting"
        exit
      end

        # place lockfile on server
      sftp.upload! lock_file, "#{sf['remote_folder']}/.synchzor/lock_file.lock"

        # download the remote manifest and removed file list
      remote_manifest = []
      deleted_list = []
      if self.sftp_file_exists("#{sf['remote_folder']}/.synchzor/", "manifest.json", sftp)
        DEFAULT_LOGGER.info " >>> copying remote manifests"
        sftp.download! server_manifest_file, remote_manifest_file
        sftp.download! server_deleted_file, remote_deleted_file
        remote_manifest = JSON.parse(File.read(remote_manifest_file))
        deleted_list = JSON.parse(File.read(remote_deleted_file))
      end

        # delete local files which the server says to delete
      DEFAULT_LOGGER.info " >>> deleting local files per server"
      deleted_list.each do |deleted_file|
        local_file = "#{sf['local_folder']}/#{deleted_file["local_path"]}"
        if File.file?(local_file) && File.atime(local_file) <= sf['last_sync_timestamp']
          DEFAULT_LOGGER.info "removing #{local_file}"
          File.delete(local_file)
        elsif File.file?(local_file) && File.atime(local_file) > sf['last_sync_timestamp']
          deleted_list.delete_if {|hash| hash["local_path"] == deleted_file["local_path"] }
        end
      end

        # create hashes for local files, load updated_at timestamps from them
      local_files = []
      Dir.glob( File.join(sf['local_folder'], '**', '*') ) { |file| local_files << file }
      files = []
      folders = []
      local_files.each do |f|
        if !f.include?(".conflict") && !File.directory?(f)
          l = f.dup
          l.sub!(sf['local_folder'] + "/","")
          l.sub!(sf['local_folder'],"")
          files << {
              "full_path" => f,
              "local_path" => l,
              "md5" => Digest::MD5.hexdigest(File.read(f)),
              "update_time" => File.mtime(f),
              "access_time" => File.atime(f),
              "status" => nil
          }

        end
        if File.directory?(f)
          l = f.dup
          l.sub!(sf['local_folder'] + "/","")
          l.sub!(sf['local_folder'],"")
          folders << l
        end
      end

        # ensure all needed folders exist on the server
      folders.each do |folder|
        begin
          sftp.mkdir! "#{sf['remote_folder']}/#{folder}/"
        rescue Net::SFTP::StatusException => e
        end
      end

        # compare local files to manifest (files are same, local_new, local_deleted, server_new, conflict)
      files.each do |file|
        status = "local_new"
        remote_manifest.each do |m|
          if m["needed?"].nil? && m["local_path"] == file["local_path"]
            if m["md5"] == file["md5"]
              status = "same"
              m["needed?"] = false
              break
            elsif m["md5"] != file["md5"]
              if file["update_time"] > m["update_time"].to_datetime
                status = "server_new"
                m["needed?"] = true
              end
              if file["update_time"] <= m["update_time"].to_datetime
                status = "conflict"
                m["needed?"] = true
              end
              break
            end
          end
        end
        file["status"] = status
      end

        # update locally new files to server
      DEFAULT_LOGGER.info " >>> Uploading locally newer files"
      files.each do |file|
        if file["status"] == "local_new"
          local = file["full_path"]
          remote = "#{sf['remote_folder']}/#{file["local_path"]}"
          DEFAULT_LOGGER.info "uploading #{local} to #{remote}"
          sftp.upload! local, remote
        end
      end

        # pull new files from server and add/overwrite and deal with locally deleted files
      DEFAULT_LOGGER.info " >>> Downloading server newer files and noting local deletions"
      remote_manifest.each do |m|
        if m["needed?"] == true || m["needed?"].nil? #nil = a file the server has but it not local
          remote = "#{sf['remote_folder']}/#{m["local_path"]}"
          local = "#{sf['local_folder']}/#{m["local_path"]}"
          if m["access_time"].to_datetime > sf['last_sync_timestamp']
            DEFAULT_LOGGER.info "downloading #{remote} to #{local}"
            parts = m["local_path"].split("/")
            if parts.count > 1
              folder_needed = sf['local_folder']
              parts.each do |part|
                folder_needed = "#{folder_needed}/#{part}"
                Dir::mkdir(folder_needed) if !File.directory?(folder_needed) && part != parts[-1]
              end
            end
            sftp.download! remote, local
            files << {
                "full_path" => local,
                "local_path" => m["local_path"],
                "md5" => Digest::MD5.hexdigest(File.read(local)),
                "update_time" => File.mtime(local),
                "access_time" => m["access_time"],
                "status" => nil
            }
          else
            DEFAULT_LOGGER.info "removing #{remote} from server"
            sftp.remove! remote
            deleted_list << {
                "local_path" => m["local_path"],
                "timestamp" => Time.now
            }
          end
        end
      end

        # pull conflicting files from server and append .conflict to them
      DEFAULT_LOGGER.info " >>> Downloading conflicting files (will have .conflict appended to the name)"
      files.each do |file|
        if file["status"] == "conflict"
          local = file["full_path"] + ".conflict"
          remote = "#{sf['remote_folder']}/#{file["local_path"]}"
          DEFAULT_LOGGER.info "downloading #{local} to #{remote}"
          sftp.download! remote, local
        end
      end

        # generate manifest and push to server
      files.each do |file|
        file["status"] = nil
      end
      File.open(local_manifest_file, 'w') {|f| f.write(files.to_json) }
      sftp.upload! local_manifest_file, server_manifest_file

      File.open(remote_deleted_file, 'w') {|f| f.write(deleted_list.to_json) }
      sftp.upload! remote_deleted_file, server_deleted_file

        # remove lockfile on server
      sftp.remove! "#{sf['remote_folder']}/.synchzor/lock_file.lock"
    end

    sf['last_sync_timestamp'] = Time.now
    new_db << sf
    @DB = new_db
    self.save_db

    DEFAULT_LOGGER.info "Complete"

  end

  def self.remote_clean
    self.load_db
    params = self.load_params
    found = false
    sf = {}
    @DB.each do |sf_|
      if params["local_folder"] == sf_["local_folder"]
        found = true
        sf = sf_.dup
        break
      end
    end
    unless found
      puts "this local_folder is not found, and not not being synched"
      exit
    end

    DEFAULT_LOGGER.info "removing all files and folders from #{sf['remote_folder']} @ #{sf['host']}"
    Net::SFTP.start(sf['host'],sf['username'], :password => sf['password']) do |sftp|
      remote_files = []
      sftp.dir.glob(sf['remote_folder'], "**/*") { |f| remote_files << f }
      remote_files.each do |f|
        if f.file?
          DEFAULT_LOGGER.info "removing #{f.name} from the server (file)"
          sftp.remove! "#{sf['remote_folder']}/#{f.name}"
        end
      end
      remote_folders = []
      sftp.dir.glob(sf['remote_folder'], "**/*") { |f| remote_folders << f }
      remote_folders = remote_folders.sort_by {|x| -x.name.length}
      remote_folders.each do |f|
        if f.directory?
          DEFAULT_LOGGER.info "removing #{f.name} from the server (dir)"
          sftp.rmdir! "#{sf['remote_folder']}/#{f.name}/"
        end
      end
      manifest = "#{sf['remote_folder']}/.synchzor/manifest.json"
      begin
        sftp.remove! manifest
      rescue
      end
    end
  end

  def self.show
    self.load_db
    puts "folders being synched:"
    @DB.each do |folder|
      ap folder
    end
  end

  def self.add
    self.load_db
    params = self.load_params
    ["local_folder","username","host","password"].each do |req|
      unless params.include?(req)
        puts "#{req} is required to create a new synch folder"
        exit
      end
    end
    if File.directory?(params['local_folder']) == false
      puts "local_folder doesn't exist of cannot be accessed"
      exit
    end
    params['port'] = 22 if params['port'].nil?
    params['last_sync_timestamp'] = Time.at(0)
    params['remote_folder'] = "synchzor/#{params['local_folder'].split("/").last}" if params['remote_folder'].nil?
    connected = false
    Net::SFTP.start(params['host'],params['username'], :password => params['password']) do |sftp|
      connected = true
    end
    if connected == false
      puts "cannot connect using these settings"
      exit
    else
      puts "ensuring #{params['remote_folder']} exists on #{params['host']}"
      begin
        Net::SFTP.start(params['host'],params['username'], :password => params['password']) do |sftp|
          parts = params['remote_folder'].split("/")
          composite = ""
          parts.each do |part|
            composite = composite + part + "/"
            sftp.stat!(composite) do |response|
              unless response.ok?
                sftp.mkdir! composite
              end
            end
          end
          sftp.mkdir! params['remote_folder'] + "/.synchzor/"
        end
      rescue Net::SFTP::StatusException => e
      end
    end
    new_entry = {}
    new_entry["local_folder"] = params["local_folder"]
    new_entry["username"] = params["username"]
    new_entry["host"] = params["host"]
    new_entry["password"] = params["password"]
    new_entry["last_sync_timestamp"] = params["last_sync_timestamp"]
    new_entry["remote_folder"] = params["remote_folder"]
    @DB << new_entry
    self.save_db
  end

  def self.remove
    self.load_db
    params = self.load_params
    if params["local_folder"].nil?
      puts "local_folder is required"
      exit
    end
    found = false
    new_db = []
    @DB.each do |sf|
      if sf['local_folder'] == params["local_folder"]
        found = true
        break
      else
        new_db << sf
      end
    end
    if found
      @DB = new_db
      puts "no longer synching #{params["local_folder"]}"
      self.save_db
    else
      puts "#{params["local_folder"]} is not being tracked. check with the show command"
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
    File.delete(DB_FILE) if File.file?(DB_FILE)
    DEFAULT_LOGGER.info "Old DB Deleted"
  end

  private

  def self.load_db
    if File.file?(DB_FILE)
      file = File.open(DB_FILE)
      contents = file.read
      @DB = JSON.parse(contents)
    else
      @DB = []
    end
  end

  def self.save_db
    if @DB != []
      File.open(DB_FILE, 'w') {|f| f.write(@DB.to_json) }
    else
      self.delete_db
    end
  end

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
        params[parts[0]] = parts[1]
      end
    end
    params
  end

end