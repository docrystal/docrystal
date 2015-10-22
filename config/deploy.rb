# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'docrystal'
set :repo_url, 'git@github.com:docrystal/docrystal.git'

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/var/docrystal'

# Default value for :scm is :git
set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

set :linked_files, fetch(:linked_files, []).push(
  'config/database.yml',
  'config/fog.yml',
  'config/schedule.yml',
  'config/secrets.yml',
  'config/sidekiq.yml'
)

set :linked_dirs, fetch(:linked_dirs, []).push(
  'log',
  'tmp/pids',
  'tmp/cache',
  'tmp/sockets',
  'vendor/bundle',
  'public/system'
)

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 3
set :keep_assets, 2

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'unicorn:restart'
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

  namespace :check do
    task :upload_linked_files do
      on roles(:app), in: :groups, limit: 3 do
        fetch(:linked_files).each do |file|
          upload!(file, "#{shared_path}/#{file}.tmpl")
        end
      end
    end

    before :linked_files, 'deploy:check:upload_linked_files'
  end
end
