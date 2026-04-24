module Registry
  class ApplicationController < ActionController::Base
    include Engine.routes.url_helpers

# Useful for debugging errors that don't show up in the logs/console
#    rescue_from Exception do |e|
#      pp :error, e, e.backtrace
#    end
  end
end
