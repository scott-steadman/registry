def next?
  File.basename(__FILE__) == "Gemfile.next"
end
source "http://www.rubygems.org"

gemspec

gem 'next_rails'

if next?
  gem 'rails', '~> 3.1.0'
else
  gem 'rails', '~> 3.0.0'
end

group :development, :test do
  gem 'method_source'
  # Rails 3.0 needs Rake < 13 due to rake_loader compatibility
  gem 'rake', '< 13'
  gem 'simplecov', :require => false
  gem 'sqlite3', '1.6.9'
  # Versions after 3.6.2 have a bug that prevents bundle exec bin/test from running
  gem 'test-unit', '3.6.2'
end
