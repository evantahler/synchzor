log_level = "info"

# puts and log all output
class TeeLogger < ActiveSupport::BufferedLogger
  cattr_accessor :verbose
  attr_accessor :extra_streams
  self.verbose = true
  def initialize(log, level = DEBUG)
    super
    self.extra_streams = []
    self.extra_streams << $stdout if verbose
  end

  def add(severity, message = nil, progname = nil, &block)
    message = "#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} | #{message}"
    self.extra_streams.each{|s| s.puts message } if @level <= severity
    super(severity, message, progname, &block)
  end
end

logdir = "#{RAILS_ROOT}/log"
DEFAULT_LOGGER = TeeLogger.new("#{logdir}/#{RAILS_ENV}.log", ActiveSupport::BufferedLogger::Severity::const_get(log_level.upcase))