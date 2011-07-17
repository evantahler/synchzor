class Synchzor < Object

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
    puts "Current Settings:"
    all_settings = DBSetting.all
    if all_settings.count > 0
      all_settings.each do |s|
        puts "  #{s.key} => #{s.value}"
      end
    end
  end

  private

  def self.start_connection
    db_config = YAML::load(File.open("#{RAILS_ROOT}/db/config.yml"))
    ActiveRecord::Base.establish_connection(db_config['synchzor'])
  end

end