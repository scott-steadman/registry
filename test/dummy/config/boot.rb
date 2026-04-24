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

# Patch Rails 3.2 gem files for Ruby 2.7+ compatibility before requiring rails
def patch_rails_for_ruby_27
  return unless defined?(Gem)

  # Patch ActiveSupport for Rails 3.2
  as_gem_spec = Gem.loaded_specs.values.find { |spec|
    spec.name == 'activesupport' && spec.version.to_s.start_with?('3.2.')
  }
  if as_gem_spec
    # Patch ActiveSupport duplicable for Rails 3.2 BigDecimal.new compatibility with Ruby 2.7+
    duplicable_file = File.join(as_gem_spec.full_gem_path, 'lib/active_support/core_ext/object/duplicable.rb')
    if File.exist?(duplicable_file)
      content = File.read(duplicable_file)
      # Fix: BigDecimal.new doesn't exist in Ruby 2.6+
      if content.include?("BigDecimal.new('4.56')")
        content.gsub!("BigDecimal.new('4.56')", "BigDecimal('4.56')")
        File.write(duplicable_file, content)
      end
    end
  end

  # Patch ActiveRecord sqlite3_adapter to allow newer sqlite3 gem versions (Rails 3.2)
  ar_gem_spec = Gem.loaded_specs.values.find { |spec| spec.name == 'activerecord' && spec.version.to_s.start_with?('3.2.') }
  if ar_gem_spec
    sqlite3_adapter_file = File.join(ar_gem_spec.full_gem_path, 'lib/active_record/connection_adapters/sqlite3_adapter.rb')
    if File.exist?(sqlite3_adapter_file)
      content = File.read(sqlite3_adapter_file)
      # Fix: Remove version constraint for sqlite3 gem (Rails 3.2 uses ~> 1.3.5)
      if content.include?("gem 'sqlite3', '~> 1.3.5'")
        content.gsub!(/gem 'sqlite3', '~> 1\.3\.5'/, "gem 'sqlite3'")
        File.write(sqlite3_adapter_file, content)
      end
    end
  end
end

patch_rails_for_ruby_27

require 'rails/all'

# Load Rails 3.2 Ruby 2.7 compatibility patches after rails loads
rails_root = File.expand_path('../../../..', __FILE__)
rails_32_compat = File.join(rails_root, 'lib/core_ext/rails_32_ruby_27_compat')
if File.exist?("#{rails_32_compat}.rb")
  require rails_32_compat
  Rails32Ruby27Compat.apply!
end

