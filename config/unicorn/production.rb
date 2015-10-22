app_path = Pathname.new(File.expand_path(File.dirname(__FILE__) + '/../..'))

worker_processes Integer(ENV['WEB_CONCURRENCY'] || 4)
timeout 15
preload_app true

listen app_path.join('tmp/sockets/unicorn.sock').to_s
pid app_path.join('tmp/pids/unicorn.pid').to_s

stderr_path app_path.join('log/unicorn.log').to_s
stdout_path app_path.join('log/unicorn.log').to_s

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill('QUIT', File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end

before_exec do |server|
  ENV['BUNDLE_GEMFILE'] = '/var/docrystal/current/Gemfile'
end
