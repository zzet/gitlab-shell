require 'rake'

set :stages, %w(production staging)
set :default_stage, "staging"

set :application,    'gitlab-shell'
set :user,           'gitlab'
set :env,            'production'
set :deploy_to,      "/rest/u/apps/#{application}"
set :bundle_without, %w[development test]

set :rvm_type,       :system

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
end

before 'deploy:finalize_update', 'deploy:symlink_config'
after  'deploy:update', 'deploy:cleanup'
