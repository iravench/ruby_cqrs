require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'bundler'
Bundler.setup(:default, :test)
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require('ruby_cqrs')

require('fixture/typical_domain')
require('support/matchers')
