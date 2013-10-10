require 'rake'

set :stages, %w(production staging)
set :default_stage, "staging"

set :application,    'gitlab-shell'
set :user,           'gitlab'
set :env,            'production'
set :deploy_to,      "/rest/u/apps/#{application}"
set :bundle_without, %w[development test]

set :undev_ruby_version, '2.0.0-p247'

set :scm, :git
set :repository,     'git://git.undev.cc/infrastructure/gitlab-shell.git'

set :use_sudo, false
set :ssh_options, :forward_agent => true

default_run_options[:pty] = true

namespace :deploy do
  desc 'Symlinks the config.yml'
  task :symlink_config, :roles => :app do
    run "ln -nfs #{release_path}/config.yml.undev #{release_path}/config.yml"
  end

  desc 'Create log file'
  task :add_log_file, roles: :app do
    run "touch #{release_path}/gitlab-shell.log"
    run "chmod 666 #{release_path}/gitlab-shell.log"
  end
end

before 'deploy:finalize_update', 'deploy:symlink_config', 'deploy:add_log_file'
after  'deploy:update', 'deploy:cleanup'
