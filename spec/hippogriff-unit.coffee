testCase = require('nodeunit').testCase
util = require 'util'
{master} = require '../src/hippogriff'

exports.Hippogriff = testCase({
  setUp: (cb) ->
    cb()
  tearDown: (cb) ->
    cb()
  ParsesConfig: (test) ->
    test.expect 2
    config = master undefined, './spec/config/hippogriff.json'
    test.strictEqual config.workers, 2
    test.strictEqual config.port, 8000
    test.done()
  SupportsCoffeeScript: (test) ->
    test.expect 1
    config = master '/path/to/worker.coffee'
    test.strictEqual config.exec_binary, 'coffee'
    test.done()
  LaunchesChildScript: (test) ->
    test.expect 1
    config = master './spec/worker/worker.coffee'
    test.strictEqual config.exec_binary, 'coffee'
    test.done()
})