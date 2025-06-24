require_relative 'lib/spyglasses/version'

Gem::Specification.new do |spec|
  spec.name          = 'spyglasses'
  spec.version       = Spyglasses::VERSION
  spec.authors       = ['Orchestra AI, Inc.']
  spec.email         = ['support@spyglasses.io']

  spec.summary       = 'AI Agent Detection and Management for Ruby web applications'
  spec.description   = 'Spyglasses provides comprehensive AI agent detection and management capabilities for Ruby web applications, including Rails, Sinatra, and other Rack-based frameworks.'
  spec.homepage      = 'https://www.spyglasses.io'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/spyglasses/spyglasses-ruby'
  spec.metadata['documentation_uri'] = 'https://www.spyglasses.io/docs/platforms/ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/spyglasses/spyglasses-ruby/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'rack', '>= 2.0'
  spec.add_dependency 'json', '>= 2.0'
  
  # Development dependencies
  spec.add_development_dependency 'bundler', '>= 2.0'
  spec.add_development_dependency 'rake', '>= 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
  spec.add_development_dependency 'rack-test', '~> 2.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'yard', '~> 0.9'
end 