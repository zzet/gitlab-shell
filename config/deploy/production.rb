set :host,            '10.40.252.13'
set :env,             'production'
set :branch,          'master'
set :user,            'gitlab'
set :keep_releases,   5
set :deploy_to,       '/rest/u/apps/gitlab-shell'
set :rvm_ruby_string, 'ruby-1.9.3-p194@gitlab_shell'

role :app, host
role :web, host
role :db,  host, primary: true
