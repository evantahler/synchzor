RUNNING_APP_IDENTIFIER = "synchzor"

def is_app_running?(term = RUNNING_APP_IDENTIFIER)
  sys_command = "ps -ef | grep '#{term}' | grep -v grep"
  output =  `#{sys_command}`
  if output.split("/n").count > 1 #a count of 1 is myself!
    true
  else
    false
  end
end

if is_app_running?
  puts "#{RUNNING_APP_IDENTIFIER} is currently running; exiting this instance"
  exit
end