# Monkey patches for Rails 3.0.x compatibility with Ruby 2.7+
# TODO: Remove this file when upgrading to Rails 3.2+

if defined?(ActiveSupport::VERSION) && ActiveSupport::VERSION::STRING =~ /^3\.0\./

  # Fix 1: TimeZone#parse - already fixed by gem file patching in boot.rb
  # The syntax error (def parse(str, now=now)) is fixed at load time
  # Module prepending is only needed if TimeZone is already loaded
  if defined?(ActiveSupport::TimeZone)
    module TimeZoneRuby27Compat
      # No additional changes needed - gem file patching handles it
    end
    ActiveSupport::TimeZone.prepend(TimeZoneRuby27Compat)
  end

  # Fix 2: BigDecimal.yaml_as doesn't exist in newer Psych (Ruby 2.7+)
  # Define it as a no-op before ActiveSupport tries to call it
  require 'bigdecimal'
  BigDecimal.singleton_class.class_eval do
    unless respond_to?(:yaml_as)
      define_method(:yaml_as) do |tag|
        # No-op for Ruby 2.7+ where yaml_as was removed
      end
    end
  end
end
