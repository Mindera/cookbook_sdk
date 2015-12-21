require 'simplecov'
if ENV['TRAVIS']
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end
SimpleCov.start

require 'minitest'
require 'mocha/mini_test'
