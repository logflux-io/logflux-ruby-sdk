# frozen_string_literal: true

require_relative 'lib/logflux'

Gem::Specification.new do |spec|
  spec.name = 'logflux-agent-ruby-sdk'
  spec.version = LogFlux::VERSION
  spec.authors = ['LogFlux Team']
  spec.email = ['support@logflux.io']

  spec.summary = 'Lightweight Ruby SDK for communicating with LogFlux Agent'
  spec.description = 'A lightweight Ruby SDK for communicating with the LogFlux Agent via Unix socket or TCP protocols'
  spec.homepage = 'https://github.com/logflux-io/logflux-agent'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/logflux-io/logflux-agent'
  spec.metadata['changelog_uri'] = 'https://github.com/logflux-io/logflux-agent/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies - keeping minimal for lightweight SDK
  spec.add_dependency 'json', '~> 2.0'

  # Development dependencies - used by GitHub Actions only
  # DO NOT use these for local development
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end