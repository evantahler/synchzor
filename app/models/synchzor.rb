class Synchzor < Object

  require 'net/sftp'
  require 'digest'

  DB_FILE = "db/synchzor"

  def self.synch(params = nil)
    self.load_db
    params = self.load_params if params.nil?
    sf, new_db = self.load_and_check_local_folder(params)

    DEFAULT_LOGGER.info "Synching #{sf['local_folder']} to #{sf['remote_folder']} @ #{sf['host']}"

    lock_file = "#{RAILS_ROOT}/tmp/lock_file.lock"
    local_manifest_file = "#{RAILS_ROOT}/tmp/local_manifest.json"
    remote_manifest_file = "#{RAILS_ROOT}/tmp/remote_manifest.json"
    server_manifest_file = "#{sf['remote_folder']}/.synchzor/manifest.json"
    remote_deleted_file = "#{RAILS_ROOT}/tmp/removed_files.json"
    server_deleted_file = "#{sf['remote_folder']}/.synchzor/removed_files.json"

    File.open(lock_file, 'w') {|f| f.write("I am a lock file from Synchzor") }
    begin
      Net::SFTP.start(sf['host'],sf['username'], :password => sf['password']) do |sftp|

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
          if File.file?(local_file) && File.atime(local_file) <= sf['last_sync_timestamp'].to_datetime
            local_delete_dir = File.dirname(local_file)
            DEFAULT_LOGGER.info "removing #{local_file}"
            File.delete(local_file)
            if Dir["#{local_delete_dir}/*"].count == 0 && sf['local_folder'] != local_delete_dir
              DEFAULT_LOGGER.info "removing #{local_delete_dir} as it is now empty"
              Dir.delete(local_delete_dir)
            end
          elsif File.file?(local_file) && File.atime(local_file) > sf['last_sync_timestamp'].to_datetime
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
            self.create_remote_file_lock(sf, file["local_path"], sftp)
            sftp.upload! local, remote
            self.remove_remote_file_lock(sf, file["local_path"], sftp)
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
              if self.is_remote_file_locked?(sf, m["local_path"], sftp)
                puts "someone else is modifying this file, exiting"
                exit
              end
              unless self.sftp_file_exists(sf['remote_folder'], m["local_path"], sftp)
                puts "file is missing from server, skipping"
              else
                sftp.download! remote, local
                files << {
                    "full_path" => local,
                    "local_path" => m["local_path"],
                    "md5" => Digest::MD5.hexdigest(File.read(local)),
                    "update_time" => File.mtime(local),
                    "access_time" => m["access_time"],
                    "status" => nil
                }
              end
            else
              DEFAULT_LOGGER.info "removing #{remote} from server"
              sftp.remove! remote if self.sftp_file_exists(sf['remote_folder'], m["local_path"], sftp)
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
      end
    rescue Net::SSH::AuthenticationFailed => e
      puts "Cannot connect using these credentials"
      exit
    rescue SocketError
      puts "Cannot connect to this host: #{sf['host']}"
      exit
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
    sf, new_db = self.load_and_check_local_folder(params)

    DEFAULT_LOGGER.info "removing all files and folders from #{sf['remote_folder']} @ #{sf['host']}"
    begin
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
    rescue Net::SSH::AuthenticationFailed => e
      puts "Cannot connect using these credentials"
      exit
    rescue SocketError
      puts "Cannot connect to this host: #{sf['host']}"
      exit
    end
  end

  def self.list
    self.load_db
    puts "folders being synched:"
    @DB.each do |folder|
      ap folder
    end
  end

  def self.add
    self.load_db
    params = self.load_params
    if params["local_folder"].nil?
      puts "local_folder not given, assuming you want to synch this folder '#{@@starting_dir}'"
      params["local_folder"] = @@starting_dir
    end
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
          needed_remote_folders = []
          parts.each do |part|
            composite = composite + part + "/"
            needed_remote_folders << composite.dup
          end
          needed_remote_folders.each do |folder|
            begin
              sftp.stat!(folder) do |response|
                unless response.ok?
                  sftp.mkdir! folder
                end
              end
            rescue Net::SFTP::StatusException => e
            end
          end
          begin
            sftp.mkdir! params['remote_folder'] + "/.synchzor/"
          rescue Net::SFTP::StatusException => e
          end
        end
      rescue Net::SSH::AuthenticationFailed => e
        puts "Cannot connect using these credentials"
        exit
      rescue SocketError
        puts "Cannot connect to this host: #{sf['host']}"
        exit
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
    puts "Added!"
  end

  def self.remove
    self.load_db
    params = self.load_params
    sf, new_db = self.load_and_check_local_folder(params)
    @DB = new_db
    DEFAULT_LOGGER.info "no longer synching #{params["local_folder"]}"
    self.save_db
  end

  def self.delete_db
    File.delete(DB_FILE) if File.file?(DB_FILE)
    DEFAULT_LOGGER.info "Old DB Deleted"
  end

  def self.all
    DEFAULT_LOGGER.info "synching all known folders"
    DEFAULT_LOGGER.info ""
    self.load_db
    @DB.each do |f|
      self.synch(f)
    end
    DEFAULT_LOGGER.info "all complete"
  end







  private






  def self.create_remote_file_lock(sf, local_path, sftp)
    full_remote_path = sf['remote_folder'] + '/' + local_path
    hash = Digest::MD5.hexdigest(full_remote_path)
    lock_file = "#{sf['remote_folder']}/.synchzor/#{hash}.lock"
    if self.is_remote_file_locked?(sf, local_path, sftp)
      DEFAULT_LOGGER.info "the file #{local_path} is being modified by someone else. exiting"
      exit
    end
    sftp.file.open(lock_file, "w") do |f|
      f.puts "lock"
    end
  end

  def self.remove_remote_file_lock(sf, local_path, sftp)
    full_remote_path = sf['remote_folder'] + '/' + local_path
    hash = Digest::MD5.hexdigest(full_remote_path)
    lock_file = "#{sf['remote_folder']}/.synchzor/#{hash}.lock"
    unless self.is_remote_file_locked?(sf, local_path, sftp)
      DEFAULT_LOGGER.info "the file #{local_path} is not locked by you. exiting"
      exit
    end
    sftp.remove! lock_file
  end

  def self.is_remote_file_locked?(sf, local_path, sftp)
    full_remote_path = sf['remote_folder'] + '/' + local_path
    hash = Digest::MD5.hexdigest(full_remote_path)
    hash_file = "#{hash}.lock"
    return true if self.sftp_file_exists("#{sf['remote_folder']}/.synchzor/", hash_file, sftp)
    false
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

  def self.load_and_check_local_folder(params = nil)
    params = self.load_params if params.nil?
    found = false
    sf = {}
    new_db = []

    if params["local_folder"].nil?
      params["local_folder"] = @@starting_dir
    end

    if params["local_folder"].nil?
      puts "local_folder is required"
      exit
    end

    @DB.each do |sf_|
      if params["local_folder"] == sf_["local_folder"]
        found = true
        sf = sf_.dup
      else
        new_db << sf_
      end
    end
    unless found
      puts "this local_folder '#{params["local_folder"]}' is not setup to be synched"
      exit
    end
    [sf, new_db]
  end

end