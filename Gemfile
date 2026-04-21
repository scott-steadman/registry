
def next?
  File.basename(__FILE__) == "Gemfile.next"
end

source "http://www.rubygems.org"

gemspec

gem 'next_rails'

if next?
  gem 'rails', '~> 3.0.0'
else
  # Rails LTS sources for free Community plan
  git 'https://github.com/makandra/rails.git', :branch => '2-3-lts' do
    gem 'rails', '~>2.3.18'
  #  gem 'actionmailer',     :require => false
    gem 'actionpack',       :require => false
    gem 'activerecord',     :require => false
  #  gem 'activeresource',   :require => false
    gem 'activesupport',    :require => false
    gem 'railties',         :require => false
  end
end

group :development, :test do
  gem 'method_source'
#  gem 'mocha', '0.11.4', :require => false
  # Rails 3.0 needs Rake < 13 due to rake_loader compatibility
  gem 'rake', '< 13'
  gem 'simplecov',       :require => false
  gem 'sqlite3', '1.6.9'
  # Rails-LTS uses test-unit 3.1.5
  # Versions after 3.6.2 have a bug that prevents bundle exec bin/test from running
  gem 'test-unit', '3.6.2'
end
