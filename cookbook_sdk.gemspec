# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cookbook_sdk/version'
require 'English'

Gem::Specification.new do |spec|
  spec.name          = 'cookbook_sdk'
  spec.version       = CookbookSDK::VERSION
  spec.authors       = ['Mindera']
  spec.email         = ['social@mindera.com']
  spec.summary       = 'cookbook sdk'
  spec.description   = IO.read(File.join(File.dirname(__FILE__), 'README.md'))
  spec.homepage      = 'https://github.com/mindera/cookbook_sdk'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'bundler', '~> 1.9'
  spec.add_dependency 'rake', '~> 10.4'
  spec.add_dependency 'highline', '~> 1.7.8'

  spec.add_development_dependency 'chef'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'coveralls'
end
