module Registry
  class Wrapper

    def initialize(hash, parent_path='')
      @parent_path = parent_path
      @hash = hash.dup
    end

    def method_missing(method, *args)
      super
    rescue NoMethodError
      raise unless exists?(method)
      add_methods_for(method)
      send(method, *args)
    end

    def to_hash
      @hash
    end

    def exists?(method)
      @hash.key?(hash_key(method_name(method)))
    end

    def with(config_hash, &block)
      result = nil
      orig_config = {}

      @saved_prevent_reset = Registry.prevent_reset?
      begin
        config_hash.each do |kk,vv|
          orig_config[kk] = self.send(kk)
          self.send("#{kk}=", vv, false)
        end

        Registry.prevent_reset!
        result = block.call
      ensure
        Registry.allow_reset! unless @saved_prevent_reset
        orig_config.each { |kk,vv| self.send("#{kk}=", vv, false) }
      end

      result
    end

    def merge(*args)
      result = entry.merge(*args)
      @hash  = entry.export
      result
    end

    def ensure_folder_exists(folder_key, new_attrs={})
      return nil if to_hash.keys.include?(folder_key)
      entry.create_folder(new_attrs.merge(:key => folder_key))
      Registry.reset
      true
    end

  private

    def method_name(method)
      method.to_s.sub(/[\?=]{0,1}$/, '')
    end

    def hash_key(method)
      @hash.keys.find {|key| key.to_s == method.to_s} || method
    end

    def add_methods_for(method)
      method = method_name( method )

      self.class_eval %{

        def #{method}                                               # def foo
          key = hash_key('#{method}')                               #   key = hash_key('foo')
          ret = @hash[key]                                          #   ret = @hash[key]
          if ret.is_a?(Hash)                                        #   if ret.is_a?(Hash)
            path = @parent_path + '/#{method}'                      #     path = @parent_path + '/foo'
            ret = self.class.new(ret, path)                         #     ret = self.class.new(ret, path)
            @hash[key] = ret                                        #     @hash[key] = ret
          elsif ret.is_a?(String)                                   #   elsif ret.is_a?(String)
            ret = Registry::Transcoder.from_db(ret)                 #     ret = Registry::Transcoder.from_db(ret)
          end                                                       #   end
          ret                                                       #   ret
        end                                                         # end

        def #{method}=(value, save=true)                            # def foo=(value, save=true)
          key = hash_key('#{method}')                               #   key = hash_key('foo')
          @hash[key] = value                                        #   @hash[key] = value
          update(key, value) if save                                #   update(key, value) if save
        end                                                         # end

        def #{method}?                                              # def foo?
          !!@hash[hash_key('#{method}')]                            #   !!@hash[hash_key('foo')]
        end                                                         # end

      }, __FILE__, __LINE__
    end

    def update(key, value)
      entry.child(key).update_attributes(:value => value)
    end

    def entry
      @entry ||= Entry.root.child(@parent_path)
    end

  end # class Wrapper

end # module Registry