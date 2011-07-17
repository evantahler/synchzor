ENV["RAILS_ENV"] = 'synchzor'
RAILS_ENV = ENV["RAILS_ENV"] unless defined?(RAILS_ENV)
RAILS_ROOT = File.expand_path(File.dirname(__FILE__) + '/../..') unless defined?(RAILS_ROOT)