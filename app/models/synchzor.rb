class Synchzor < Object

  def self.run
    DEFAULT_LOGGER.info "Starting Synchzor"
    self.start_connection
  end

  def self.reset
    DEFAULT_LOGGER.info "Starting Synchzor Reset"
    self.start_connection
  end

  private

  def self.start_connection
    ActiveRecord::Base.establish_connection(Setting.synchzor)
  end

end