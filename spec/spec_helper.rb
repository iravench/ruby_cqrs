require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'bundler'
Bundler.setup(:default, :test)
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require('support/matchers')
require('ruby_cqrs')

require('fixture/typical_domain')
