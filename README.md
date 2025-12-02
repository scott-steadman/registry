# Registry Engine

This engine provides a registry mechanism which can be used to enable/disable
functionality or change parameters at runtime.

## Installation

Add the following lines to the specified files:

```ruby
# Gemfile
gem 'registry', :git => 'https://github.com/scott-steadman/registry.git', :branch => 'rails-8'

# config/routes.rb
Rails.application.routes.draw do
  # Update config/initialiers/registry.rb if the mount point changes.
  mount Registry::Engine => '/foo'
  ...
end

# config/initializers/registry.rb
Registry.configure do |config|

  # This permission check is used to access the registry UI
  config.permission_check { redirect_to login_path and return false unless current_user.admin? }

  # The layout used by the registry UI
  config.layout = 'admin'

  # user id to blame when updating entries
  config.user_id = { current_user.id }
end

# app/controllers/api_controller.rb
class ApiController < ActionController::Base

  before_action :ensure_api_enabled, :check_rate_limit

  ...

private

  def ensure_api_enabled
    raise ServiceUnavailableError.new('API Disabled') unless Registry.api.enabled?
  end

  def check_rate_limit
    cache_key = "api_rate_limit_p#{current_user.id}"

    requests = Rails.cache.read(cache_key).to_i
    if requests >= Registry.api.request_limit
      # Over the limit.
      raise ForbiddenError.new('Rate limit exceeded.')
    else
      # Under the limit.
      Rails.cache.write(cache_key, (requests+1).to_s, :expires_in => Registry.api.request_window)
    end
  end

end # class ApiController

# config/registry.yml
defaults:
  api_enabled:        true
  api_request_limit:  1
  api_request_window: 1000

development:
  api_request_window: 100

test:
  api_request_window: 100

production:
  api_enabled:        false
  api_request_limit:  10
  api_request_window: 10000


# lib/tasks/my_tasks.rake
desc 'Import configuration'
task :import_configuration => [:environment] do
  Registry.import("#{Rails.root}/config/registry.yml", :verbose => !Rails.env.test?)
end

```

## Initital import

```sh
bundle exec rake import_configuration
```

### Sprockets changes

If you're using the sprockets asset pipeline add the following line to app/assets/config/manifest.js.

```javascript
//= link registry
```

## Development

## Annotating models

```sh
bundle exec annotaterb models -p before
``

## Testing

### Running Automated Tests

```sh
# run all tests and generate coverage report in coverage subdir
bundle exec rails db:create db:migrate
bundle exec rails test
```

### Manual Integration Testing

```sh
# populate dummy app database
bundle exec rails db:create
bundle exec rails db:seed

# Spin up the server
bundle exec rails server -b 0.0.0.0
```

## Upgrading

```sh
git checkout -b rails-x
gem install rails-x.y.z

# generate new engine subdir.
rails plugin new registry --rc=.railsrc

# copy files over and test.
```

This will create a new engine in the registry subdirectory.
You should copy the files over, then make sure the tests pass.

## References

[Rails Engines](https://guides.rubyonrails.org/engines.html)
