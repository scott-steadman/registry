require_relative "lib/registry/version"

Gem::Specification.new do |spec|
  spec.name        = "registry"
  spec.version     = Registry::VERSION
  spec.authors     = ["Michael Berkovich", "Scott Steadman"]
  spec.email       = ['michael@geni.com', 'scott.steadman@geni.com']
  spec.homepage    = "https://github.com/scott-steadman/registry"
  spec.summary     = spec.description
  spec.description = %q{Engine for controlling application behavior through configurable properties}
  spec.license     = 'MIT'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency 'rails', '~> 8.0.0'
end
