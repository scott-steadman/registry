require 'rubygems'
gemfile = File.expand_path('../../../../Gemfile', __FILE__)

if File.exist?(gemfile)
  ENV['BUNDLE_GEMFILE'] = gemfile
  require 'bundler'
  Bundler.setup
end

$:.unshift File.expand_path('../../../../lib', __FILE__)

# Patches for Rails 3.0 on Ruby 2.7+
# Add a no-op yaml_as method to BigDecimal for Psych 4.x compatibility
if defined?(BigDecimal) && !BigDecimal.respond_to?(:yaml_as)
  BigDecimal.define_singleton_method(:yaml_as) { |tag| }
end

# Patch Rails 3.0/3.1 gem files for Ruby 2.7+ compatibility before requiring rails
def patch_rails_for_ruby_27
  # Find Rails 3.0 or 3.1 gems and patch for Ruby 2.7+ compatibility
  return unless defined?(Gem)

  # Patch ActiveSupport TimeZone for Ruby 2.7+ syntax
  as_gem_spec = Gem.loaded_specs.values.find { |spec|
    spec.name == 'activesupport' && (spec.version.to_s.start_with?('3.0.') || spec.version.to_s.start_with?('3.1.'))
  }
  if as_gem_spec
    timezone_file = File.join(as_gem_spec.full_gem_path, 'lib/active_support/values/time_zone.rb')
    if File.exist?(timezone_file)
      content = File.read(timezone_file)
      # Fix: def parse(str, now=now) - circular argument reference (syntax error in Ruby 2.7+)
      if content.include?('def parse(str, now=now)')
        content.gsub!(/def parse\(str, now=now\)/, "def parse(str, now=nil)\n      now ||= self.now")
        File.write(timezone_file, content)
      end
    end
  end

  # Patch ActiveRecord sqlite3_adapter to allow newer sqlite3 gem versions (Rails 3.1 only)
  ar_gem_spec = Gem.loaded_specs.values.find { |spec| spec.name == 'activerecord' && spec.version.to_s.start_with?('3.1.') }
  if ar_gem_spec
    sqlite3_adapter_file = File.join(ar_gem_spec.full_gem_path, 'lib/active_record/connection_adapters/sqlite3_adapter.rb')
    if File.exist?(sqlite3_adapter_file)
      content = File.read(sqlite3_adapter_file)
      # Fix: Remove version constraint for sqlite3 gem
      if content.include?("gem 'sqlite3', '~> 1.3.4'")
        content.gsub!(/gem 'sqlite3', '~> 1\.3\.4'/, "gem 'sqlite3'")
        File.write(sqlite3_adapter_file, content)
      end
    end

    # Patch ActiveRecord HasManyAssociation for Ruby 2.7+ (Rails 3.1 only)
    # This must be done before the file is loaded since it has syntax errors
    has_many_file = File.join(ar_gem_spec.full_gem_path, 'lib/active_record/associations/has_many_association.rb')
    if File.exist?(has_many_file)
      content = File.read(has_many_file)
      # Fix circular argument references: def method(reflection = reflection)
      if content.include?('def has_cached_counter?(reflection = reflection)')
        content.gsub!('def has_cached_counter?(reflection = reflection)',
                      "def has_cached_counter?(reflection_param = nil)\n          reflection_param ||= reflection")
        content.gsub!('def cached_counter_attribute_name(reflection = reflection)',
                      "def cached_counter_attribute_name(reflection_param = nil)\n          reflection_param ||= reflection")
        content.gsub!('def update_counter(difference, reflection = reflection)',
                      "def update_counter(difference, reflection_param = nil)\n          reflection_param ||= reflection")
        content.gsub!('def inverse_updates_counter_cache?(reflection = reflection)',
                      "def inverse_updates_counter_cache?(reflection_param = nil)\n          reflection_param ||= reflection")

        content.gsub!(/owner\.attribute_present\?\(cached_counter_attribute_name\(reflection\)\)/,
                      'owner.attribute_present?(cached_counter_attribute_name(reflection_param))')
        content.gsub!('"\#{reflection.name}_count"', '"\#{reflection_param.name}_count"')
        content.gsub!(/if has_cached_counter\?\(reflection\)/, 'if has_cached_counter?(reflection_param)')
        content.gsub!(/counter = cached_counter_attribute_name\(reflection\)/,
                      'counter = cached_counter_attribute_name(reflection_param)')
        content.gsub!(/counter_name = cached_counter_attribute_name\(reflection\)/,
                      'counter_name = cached_counter_attribute_name(reflection_param)')
        content.gsub!(/reflection\.klass\.reflect_on_all_associations/, 'reflection_param.klass.reflect_on_all_associations')
        File.write(has_many_file, content)
      end
    end
  end
end

patch_rails_for_ruby_27

require 'rails/all'

# Load Ruby 2.7 compatibility patches for Rails 3.0 after rails loads
rails_root = File.expand_path('../../../..', __FILE__)
rails_30_compat = File.join(rails_root, 'lib/core_ext/rails_30_ruby_27_compat')
require rails_30_compat if File.exist?("#{rails_30_compat}.rb")

# Load Rails 3.1 Ruby 2.7 compatibility patches after rails loads
rails_31_compat = File.join(rails_root, 'lib/core_ext/rails_31_ruby_27_compat')
if File.exist?("#{rails_31_compat}.rb")
  require rails_31_compat
  Rails31Ruby27Compat.apply!
end