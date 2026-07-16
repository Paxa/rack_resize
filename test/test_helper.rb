require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/mock'
require_relative '../lib/rack_resize'

Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)
