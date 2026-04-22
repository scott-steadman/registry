# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require File.expand_path('../application', __FILE__)
Registry::Application.initialize!
