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

  private

  def self.start_connection
    db_config = YAML::load(File.open("#{RAILS_ROOT}/db/config.yml"))
    ActiveRecord::Base.establish_connection(db_config['synchzor'])
  end

end