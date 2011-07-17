files = Dir["#{RAILS_ROOT}/app/models/*"].collect
files.each do |file|
  require file
end