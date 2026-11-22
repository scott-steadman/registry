
module Registry
  class Config

    attr_accessor :cache, :auto_create_root

    def initialize
      @cache            = nil
      @auto_create_root = true
    end

    # Permission check used by the Registry UI.
    #
    # call-seq:
    #   Registry.configure do |config|
    #     config.permission_check { current_user.admin? }
    #   end
    def permission_check(*args, &blk)
      if block_given?
        silence_warnings do
          define_controller_method(:permission_check, &blk)
          Registry::RegistryController.before_action(:permission_check)
        end
      else
        Registry::RegistryController.skip_before_action(:permission_check, :raise => false)
        remove_controller_method(:permission_check)
      end
    end

    # Layout used by the Registry UI.
    #
    # call-seq:
    #   Registry.configure do |config|
    #     config.layout = 'admin'
    #   end
    def layout=(value)
      Registry::RegistryController.send(:layout, value)
    end

    # Method used by Registry UI to obtain the current user id.
    #
    # call-seq:
    #   Registry.configure do |config|
    #     config.user_id { current_user.id }
    #   end
    def user_id(*args, &blk)
      if block_given?
        silence_warnings {define_controller_method(:registry_user_id, :private, &blk)}
      else
        remove_controller_method(:registry_user_id)
      end
    end

    # Method used by Registry UI to obtain a name for a given user id.
    #
    # call-seq:
    #   Registry.configure do |config|
    #     config.user_name { |id| User.find(id).name }
    #   end
    def user_name(&blk)
      if block_given?
        silence_warnings {define_controller_method(:registry_user_name, :private, &blk)}
      else
        remove_controller_method(:registry_user_name)
      end
    end

    # Set the reset_interval.
    #
    # If a registry access occurs more than +reset_interval+ seconds
    # since the last reset, Registry.reset will be called before the
    # next access occurs.
    #
    # see: reset_proc for more info.
    #
    # ==== Parameters
    #
    # * +interval+ - Interval in seconds to reset
    #
    # call-seq:
    #   Registry.configure do |config|
    #     config.reset_interval = 30.seconds
    #   end
    def reset_interval=(interval)
      should_reset_proc do
        return false if interval.nil?
        (Time.now.to_i - Registry.last_reset_time.to_i) >= interval
      end
    end

    # Specify a Proc to call to determine if the registry should be reset.
    #
    # Registry.method_missing will call this proc before each access.
    # If the proc returns true, then Registry.reset will be called before
    # the next access occurs.
    #
    # call-seq:
    #   Registry.configure do |config|
    #     config.should_reset_proc do
    #       (Time.now.to_i - Registry.last_reset_time.to_i) >= 30.seconds
    #     end
    #   end
    def should_reset_proc(&blk)
      silence_warnings do
        Registry.singleton_class.send(:define_method, :should_reset?, &blk)
      end
    end

    # Add a transcoder.
    #
    # Transcoders are used to convert native types to/from a string that is stored in the database.
    #
    # call-seq:
    #   Registry.configure.do |config|
    #
    #     # add integer transcoder
    #     config.add_transcoder do
    #       check   { |value| value.is_a?(Integer) or value =~ /\A[-+]?[\d_,]+\z/ }
    #       from_db { |string| string.to_i }
    #     end
    #
    #     # add range transcoder
    #     config.add_transcoder do
    #       check   { |value| value =~ /\.\./ }
    #
    #       from_db do |string|
    #         begin
    #           eval(value)
    #         rescue SyntaxError => ex
    #           return value unless ex.message =~ /octal/  # conversion failed, just return value
    #           from, range, to = value.match(/(.*)\s*(\.\.\.?)\s*(.*)/).to_a[1 .. -1]
    #           eval("#{from.to_i} #{range} #{to.to_i}")
    #         end
    #       end
    #     end
    #
    #     # add array transcoder
    #     config.add_transcoder do
    #       check   { |value|  value[0,1] == '[' and value[-1,1] == ']' }
    #       to_db   { |value|  "[#{value.map {|ii| Transcoder.to_db(ii)}.join(',')}]" }
    #       from_db { |string| string[1 .. -2].split(',').map {|ii| Transcoder.from_db(ii)} }
    #     end
    #
    #   end
    def add_transcoder(&block)
      instance = Transcoder::DSL.new
      instance.instance_exec(&block)
      Transcoder.transcoders << instance
    end

private

    # Module prepended to the controller that holds the configured overrides.
    def controller_overrides
      Registry::RegistryController::CONFIG_OVERRIDES
    end

    def define_controller_method(name, visibility = :public, &blk)
      controller_overrides.send(:define_method, name, &blk)
      controller_overrides.send(visibility, name)
    end

    def remove_controller_method(name)
      return unless controller_overrides.private_method_defined?(name) ||
                    controller_overrides.method_defined?(name)
      controller_overrides.send(:remove_method, name)
    end

  end
end # module Registry
