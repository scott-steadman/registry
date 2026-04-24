# Rails 3.2 compatibility patches for Ruby 2.7+
# Uses Module.prepend to fix runtime errors (frozen string issues)

module Rails32Ruby27Compat
  # Patch for ActionDispatch::Routing::RouteSet
  # Fixes frozen string modification error at runtime
  module RouteSetPatch
    def url_for(options)
      finalize!
      options = (options || {}).reverse_merge!(default_url_options)

      handle_positional_args(options)

      user, password = extract_authentication(options)
      path_segments  = options.delete(:_path_segments)
      script_name    = options.delete(:script_name)

      path = (script_name.blank? ? _generate_prefix(options) : script_name.chomp('/')).to_s.dup

      path_options = options.except(*ActionDispatch::Routing::RouteSet::RESERVED_OPTIONS)
      path_options = yield(path_options) if block_given?

      path_addition, params = generate(path_options, path_segments || {})
      path << path_addition
      params.merge!(options[:params] || {})

      ActionDispatch::Http::URL.url_for(options.merge!({
        :path => path,
        :params => params,
        :user => user,
        :password => password
      }))
    end
  end

  def self.apply!
    if defined?(ActionDispatch::Routing::RouteSet)
      ActionDispatch::Routing::RouteSet.prepend(RouteSetPatch)
    end
  end
end
