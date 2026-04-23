module Registry
  class ApplicationController < ActionController::Base
    include Engine.routes.url_helpers
  end
end
