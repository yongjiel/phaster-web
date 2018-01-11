set :application, 'phaster'
set :repo_url, 'git@bitbucket.org:wishartlab/phaster-web.git'

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

set :deploy_to, '/apps/phaster/project'
set :scm, :git
set :use_sudo, false
# set :format, :pretty
# set :log_level, :debug
# set :pty, true

set :linked_files, %w{config/database.yml}
set :linked_dirs, %w{public/downloads index log public/system public/jobs}

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
set :keep_releases, 5

set :sidekiq_config, "#{current_path}/config/sidekiq.yml"
# set :sidekiq_config, -> { File.join(shared_path, 'config', 'sidekiq.yml') }
set :sidekiq_pid,  File.join('/', 'tmp', 'phaster.sidekiq.pid')
# set :sidekiq_concurrency, 2
# set :sidekiq_queue, ['default', 'low']

namespace :deploy do
  desc 'Start application'
  task :start do
    on roles(:web) do
      within release_path do
        execute "script/puma.sh", "start"
      end
    end
  end

  desc 'Stop application'
  task :stop do
    on roles(:web) do
      within release_path do
        execute "script/puma.sh", "stop"
      end
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:web) do
      within release_path do
        execute "script/puma.sh", "restart"
      end
    end
  end

  after :publishing, :restart, :cleanup
end

# Flush all redis caches. Not necessary unless large update to database
namespace :redis do
  desc "Flushes all Redis data"
  task :flushall do
    on roles(:web) do
      execute "redis-cli", "flushall"
    end
  end
end


