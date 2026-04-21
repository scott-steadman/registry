begin
  require 'rubygems'
  require 'bundler'
rescue LoadError
  raise "Could not load the bundler gem. Install it with `gem install bundler`."
end

if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.24")
  raise RuntimeError, "Your bundler version is too old for Rails 2.3.\n" +
   "Run `gem install bundler` to upgrade."
end

begin
  # Set up load paths for all bundled gems
  ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems.\n" +
    "Did you run `bundle install`?"
end

# Patches for Rails 3.0 on Ruby 2.7+
# Add a no-op yaml_as method to BigDecimal for Psych 4.x compatibility
if defined?(BigDecimal) && !BigDecimal.respond_to?(:yaml_as)
  BigDecimal.define_singleton_method(:yaml_as) { |tag| }
end
