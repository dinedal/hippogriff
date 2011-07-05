fs = require 'fs'
util = require 'util'
path = require 'path'
{spawn} = require 'child_process'

process.on 'uncaughtException', (err) ->
  console.log 'Caught exception: ' + '\n' + util.inspect(err.stack, false, 6)

exports.master = (path_to_worker, path_to_config) ->
  config = {}
  workers = []
  
  if path.extname(path_to_worker) == '.coffee'
    config.exec_binary = 'coffee'
  else
    config.exec_binary = 'node'
  
  config.workers = 1
  
  if path_to_config?
    file_config = JSON.parse fs.readFileSync(path_to_config).toString()
    for key, value of file_config
      config[key] = value
  console.log util.inspect path_to_worker
  if path_to_worker? and path.existsSync path_to_worker
    if path_to_worker[0] == '.'
      path_to_worker = process.cwd() + '/' + path_to_worker[2..-1]
    worker = spawn "#{config.exec_binary}", ["#{path_to_worker}"], {cwd:path.dirname path_to_worker}
    worker.stdout.on 'data', (data) -> process.stdout.write data
    worker.stderr.on 'data', (data) -> process.stderr.write data
    worker.on 'exit', (code) -> process.exit code
    workers.push worker
  
  if workers.length > 0
    setInterval (() ->
      console.log "testing"
    ), 1000
  
  config