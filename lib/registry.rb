require "registry/version"
require "registry/engine"

module Registry

  DEFAULTS_KEY = 'defaults' unless defined?(DEFAULTS_KEY)

  # Configure the Registry Engine.
  #
  # The passed block will be excuted immediately.
  #
  # call-seq:
  #   Registry.configure do |config|
  #     config.cache = Rails.cache
  #   end
  #
  def self.configure
    yield configuration
  end

  # Initialize the Registry Engine.
  #
  # The passed block will be excuted after the engine is initialized
  # (ie all classes are loaded).
  #
  # call-seq:
  #   Registry.after_initialize do |config|
  #
  #     # permission check used by Registry UI
  #     config.permission_check { current_user.admin? }
  #
  #     # layout used by Registry UI
  #     config.layout = 'admin'
  #   end
  #
  def self.after_initialize
    Engine.initializer 'registry.initialize' do |app|
      yield Registry.configuration
    end
  end

  # Returns the current registry configuration
  def self.configuration
    @configuration ||= Registry::Config.new
  end

  # Access registry values.
  #
  # call-seq:
  #
  #   Registry.api.enabled?       # => true
  #   Registry.api.request_limit? # => 1
  #
  def self.method_missing(method, *args)
    reset                    if should_reset?
    load_registry_from_cache if !defined?(@registry) || @registry.nil?

    add_wrapper_methods_for(method)

    @registry.send(method, *args)
  rescue NoMethodError
    reset
    raise
  end

  # Reset the registry.
  #
  # This will force a reload next time it is accessed.
  #
  # ==== Parameters
  #
  # * +clear_cache+ - Optional, whether to clear the cache after reset.
  #
  def self.reset(clear_cache=nil)
    return if prevent_reset?
    @registry = nil
    @last_reset_time = Time.now
    self.clear_cache if clear_cache
  end

  # When the registry was last reset.
  def self.last_reset_time
    defined?(@last_reset_time) ? @last_reset_time : nil
  end

  # Import registry values from yml file.
  #
  # ==== Prameters
  #
  # * +file+ - Name of yml file.
  # * +opts+ - Additional options see examples for usage.
  #
  # ==== Options
  #
  # * <tt>:purge</tt> - if true, deletes all entries before import.
  # * <tt>:testing</tt> - if true, don't save registry values.
  #
  # ==== File Format
  #
  # yml File should be in the following format:
  #
  # defaults:
  #   api:
  #     enabled:        true
  #     request_limit:  100
  #
  # development:
  #   api:
  #     request_limit:  1
  #
  # test:
  #   api:
  #     request_limit:  1
  #
  # production:
  #   api:
  #     enabled:        false
  #
  # call-seq:
  #   Registry.import("#{Rails.root}/config/defaults.yml")
  #   Registry.import("#{Rails.root}/config/defaults.yml", :purge => true)
  #   Registry.import("#{Rails.root}/config/defaults.yml", :testing => true)
  #
  def self.import(file, opts={})
    if opts[:testing]
      hash = YAML.load_file(file)
      env  = opts.fetch(:env, Rails.env)
      hash = hash.fetch(DEFAULTS_KEY, {}).deep_merge(hash.fetch(env.to_s, {}))
      @registry = Wrapper.new(hash)
      return
    end

    if opts[:purge]
      Entry.delete_all
      Entry::Version.delete_all
    end

    Entry.import!(file, opts)
  end

  # :nodoc:
  def self.prevent_reset?
    (defined?(@prevent_reset) && @prevent_reset) || last_reset_time.to_i > get_cached_at.to_i
  end

  # Return changes made at the end of a path
  #
  # ==== Parameters
  #
  # * +path+ - path to child.
  # * +env+  - Optional, Rails environment.
  #
  # call-seq:
  #   Registry.versions('api/enabled')       #=> changes made to enabled flag.
  #   Registry.versions('api/enabled', 'qa') #=> changes made to enabled flag in QA environment.
  def self.versions(path, env=Rails.env)
    Entry.root(env).child(path).versions
  end

  def self.to_hash
    load_registry_from_cache if @registry.nil?
    @registry.to_hash
  end

protected

  # :nodoc:
  def self.prevent_reset!
    @prevent_reset = true
  end

  # :nodoc:
  def self.allow_reset!
    @prevent_reset = nil
  end

  # :nodoc:
  def self.cache_key(env=Rails.env.to_s)
    "#{env}-registry"
  end

  # :nodoc:
  def self.clear_cache(env=Rails.env.to_s)
    set_cached_at
    configuration.cache.delete(cache_key(env))
  end

  # :nodoc:
  def self.force_cache(env=Rails.env.to_s)
    set_cached_at
    cache_set(cache_key(env), Entry.root.export)
  end

private

  def self.cache_get(key)
    value = configuration.cache.read(key)
    return nil unless value
    Marshal.load(value)
  end

  def self.cache_set(key, value)
    configuration.cache.write(key, Marshal.dump(value))
    value
  end

  def self.cached_at_key
    "#{cache_key}-cached_at"
  end

  def self.set_cached_at
    cache_set(cached_at_key, Time.now.to_i)
  end

  def self.get_cached_at
    cache_get(cached_at_key)
  end

  def self.should_reset?
    false
  end

  def self.add_wrapper_methods_for(method)
    module_eval %{
      def self.#{method}(*args)
        load_registry_from_cache if @registry.nil?
        @registry.#{method}(*args)
      end
    }, __FILE__, __LINE__
  end

  def self.load_registry_from_cache
    env      = Rails.env.to_s
    reg_hash = cache_get(cache_key(env))
    reg_hash = force_cache(env) if reg_hash.try(:size).to_i < 10

    @registry = Wrapper.new(reg_hash)
  end

end # module Registry

require "registry/config"
require "registry/wrapper"
require "registry/transcoder"