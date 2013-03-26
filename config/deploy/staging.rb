set :host,            '10.40.42.123'
set :env,             'staging'
set :branch,          'staging'
set :user,            'gitlab'
set :keep_releases,   5
set :deploy_to,       '/rest/u/apps/gitlab-shell'
#set :rvm_ruby_string, 'ruby-1.9.3-p392@gitlab_shell'

role :app, host
role :web, host
role :db,  host, primary: true
