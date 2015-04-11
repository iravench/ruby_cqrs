require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'bundler'
Bundler.setup(:default, :test)
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require('ruby_cqrs')
require('ruby_cqrs/version')
require('ruby_cqrs/error')
require('ruby_cqrs/guid')
require('ruby_cqrs/domain/event')
require('ruby_cqrs/domain/aggregate')
require('ruby_cqrs/domain/snapshotable')
require('ruby_cqrs/domain/aggregate_repository')
require('ruby_cqrs/data/event_store')
require('ruby_cqrs/data/serialization')
require('ruby_cqrs/data/in_memory_event_store')

require('fixture/typical_domain')
require('support/matchers')
