source "http://www.rubygems.org"

gemspec

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

group :development, :test do
  gem 'annotate'
  gem 'method_source'
#  gem 'mocha', '0.11.4', :require => false
  gem 'rake'
  gem 'simplecov',       :require => false
  gem 'sqlite3', '1.6.9'
  gem 'test-unit', '3.6.2' # >3.6.3 have problems with elapsed_time
end

group :vscode do
  gem 'debase',           :require => false
  gem 'debug',            :require => false
  gem 'rdoc', '6.2.1.1',  :require => false
  gem 'ruby-debug-ide',   :require => false
  gem 'solargraph',       :require => false
end
