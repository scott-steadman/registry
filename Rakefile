require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'

# Check if Rails 3.0+ is loaded (after boot)
if defined?(Rails::Application)
  require File.expand_path('../config/application', __FILE__)
  Registry::Application.load_tasks
else
  require 'tasks/rails'
end
