source "http://www.rubygems.org"

gemspec

group :development, :test do
  gem 'annotaterb'
  gem 'minitest', '~> 5.0'
#  gem 'mocha', '0.11.4', :require => false
  gem 'nokogiri',  :force_ruby_platform => true
  gem 'pg', '~>1.5.0' # 1.6 requires GLIBC 2.29 which CentOS 8 Stream doesn't have
  gem 'puma'
  gem 'rake'
  gem 'simplecov',       :require => false
end

group :vscode do
  # VSCode ruby-lsp plugin uses these.
  # Normally they're installed by the plugin using .ruby-lsp/Gemfile
  # If we don't put them here, they'll be removed if we run bundle install
  gem 'prism', '~> 1.9.0',    :require => false
  gem 'rbs',                  :require => false
  gem 'ruby-lsp', '>=0.18.0', :require => false
  gem 'ruby-lsp-rails',       :require => false
end

