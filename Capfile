# Load DSL and Setup Up Stages
require 'capistrano/version'
load 'deploy'

require 'bundler/capistrano'
require 'undev/capistrano'
require 'capistrano/ext/multistage'
# Maintance sidekiq with cap
#require 'sidekiq/capistrano'
# Uncomment if you will use Airbrake notifications
#require 'airbrake/capistrano'
load 'deploy' if respond_to?(:namespace) # cap2 differentiator
load 'config/deploy' # remove this line to skip loading any of the default tasks
