module Registry

  # Configure the Registry Engine.
  #
  # call-seq:
  #   Registry.configure do |config|
  #
  #     # permission check used by Registry UI
  #     config.permission_check { current_user.admin? }
  #
  #     # layout used by Registry UI
  #     config.layout = 'admin'
  #   end
  #
  def self.configure
    yield configuration
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
    (@registry ||= RegistryWrapper.new(Entry.root)).send(method, *args)
  end

  # Reset the registry.
  #
  # This will force a reload next time it is accessed.
  #
  def self.reset
    return if @prevent_reset
    @registry = nil
  end

  # Import registry values from yml file.
  #
  # File should be in the following format:
  #
  #---
  # development:
  #   api:
  #     enabled:        true
  #     request_limit:  1
  #
  # test:
  #   api:
  #     enabled:        true
  #     request_limit:  1
  #
  # production:
  #   api:
  #     enabled:        false
  #     request_limit:  1
  #
  #---
  # call-seq:
  #   Registry.import("#{Rails.root}/config/defaults.yml")
  #   Registry.import("#{Rails.root}/config/defaults.yml", :purge => true)  # purge registry before import
  #
  def self.import(file, opts={})
    if opts[:purge]
      Entry.delete_all
      Entry::Version.delete_all
    end
    Entry.import!(file, opts)
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

private

  class RegistryWrapper

    def initialize(entry)
      @entry = entry
      @hash = {}
    end

    def method_missing(method, *args)
      super
    rescue NoMethodError
      method_name = method.to_s.sub(/[\?=]{0,1}$/, '')
      raise unless entry = @entry.children.find_by_key(method_name)
      @hash[method_name] = entry.folder? ? RegistryWrapper.new(entry) : entry.send(:decoded_value)
      add_methods_for(method)
      send(method, *args)
    end

    def to_hash
      @entry.export(@hash)
    end

    def with(config_hash, &block)
      result = nil
      orig_config = {}

      begin
        config_hash.each do |kk,vv|
          orig_config[kk] = self.send(kk)
          self.send("#{kk}=", vv)
        end

        Registry.prevent_reset!
        result = block.call
      ensure
        Registry.allow_reset!
        orig_config.each { |kk,vv| self.send("#{kk}=", vv) }
      end

      result
    end

  private

    def add_methods_for(method)
      method = method.to_s.sub(/[\?=]{0,1}$/, '')

      self.class_eval %{

        def #{method}                                         # def foo
          ret = @hash['#{method}']                            #   ret = @hash['foo']
          if ret.is_a?(Hash)                                  #   if ret.is_a?(Hash)
            ret = @hash['#{method}'] = self.class.new(ret)    #     ret = @hash['foo'] = self.class.new(ret)
          end                                                 #   end
          ret                                                 #   ret
        end                                                   # end

        def #{method}=(value)                                 # def foo=(value)
          @hash['#{method}'] = value                          #   @hash['foo'] = value
        end                                                   # end

        def #{method}?                                        # def foo?
          !!@hash['#{method}']                                #   !!@hash['foo']
        end                                                   # end

      }, __FILE__, __LINE__
    end

  end

end # module Registry
