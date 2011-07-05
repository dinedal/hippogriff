fs = require('fs')
util = require('util')
path = require('path')
{spawn, exec} = require('child_process')
{EventEmitter} = require 'events'

emitter = new EventEmitter()

process.env.PATH = process.env.PATH + "./node_modules/nodeunit/bin"

runTest = (path_to_tests) ->
  (callback) -> 
    exec 'nodeunit ' + path_to_tests, (err, stdout, stderr) ->
      console.log stdout
      process.stderr.write stderr
      callback err, null

task "spec", "Run all tests", ->
  runTest "spec/*-unit.coffee", (err) ->
    if err?
      process.stdout.on "drain", -> process.exit -1
      console.log util.inspect err

task "compile", "Compile CoffeeScript to JS", ->
  exec 'coffee -o lib/ -c src/', (err, stdout, stderr) ->
    console.log stdout
    process.stderr.write stderr
    