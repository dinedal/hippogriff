fs = require 'fs'
util = require 'util'
path = require 'path'
net = require 'net'
{spawn} = require 'child_process'

process.on 'uncaughtException', (err) ->
  console.err 'Caught exception: ' + '\n' + util.inspect(err.stack, false, 6)

  
workers = {}
config = {}

exports.master = (path_to_worker, path_to_config) ->
  # Set defaults
  if path.extname(path_to_worker) == '.coffee'
    config.exec_binary = 'coffee'
  else
    config.exec_binary = 'node'
  config.workers = 1
  config.socket = "/tmp/hippogriff.sock"
  config.checkInterval = 1000
  
  # Use user provided config for overrides
  config = load_config_file config, path_to_config
  
  socket = null
  server = net.createServer (c) ->
    c.on 'data', (data) ->
      data = data.toString()
      if data[0..4] == "PONG "
        workers[data[5..-2]].status = "okay"
      else if data[0..13] == "GOODBYE FROM "
        delete workers[data[13..-2]]
    socket = c
  
  # Start our engines....
  server.listen config.socket, () ->
    for i in [0...config.workers]
      startWorker config, path_to_worker
  
  # Monitoring of children
  setInterval (() ->
    new_workers = []
    for worker of workers
      console.log util.inspect workers[worker].status
      if workers[worker].status == "concerned"
        console.log "Worker #{worker} failed to respond, SIGKILLing..."
        workers[worker].handle.kill("SIGKILL")
        new_workers.push workers[worker]
        delete workers[worker]
    socket.write 'PING\n'
    for worker of workers
      workers[worker].status = "concerned"
    for new_worker in new_workers
      startWorker(new_worker.config, new_worker.path_to_worker)
  ), config.checkInterval
  
  # Match Unicorn's signal handling
  process.on 'SIGHUP', () ->
    # Reload config, gracefully restart all workers
    # TBD
  
  quickshutdown = () ->
    for worker of workers
      workers[worker].handle.kill("SIGKILL")
    process.exit 0
  process.on 'SIGINT', quickshutdown
  process.on 'SIGTERM', quickshutdown
  
  process.on 'SIGQUIT', () ->
    # Gracefully shutdown all workers and then quit
    # TBD
  
  process.on 'SIGUSR1', () ->
    # Reopen all log files
    # TBD
  process.on 'SIGUSR2', () ->
    # Bring up a copy of this process and workers
    # TBD
  process.on 'SIGWINCH', () ->
    # Gracefully stop all workers
    # TBD
  process.on 'SIGTTIN', () ->
    # Increment worker count
    config.workers++
    startWorker config, path_to_worker
  process.on 'SIGTTOU', () ->
    # Decerment worker count
    config.workers--
    # TBD Graceful exit
    workers[Object.keys(workers)[0]].handle.kill("SIGKILL")
    delete workers[worker]
  
  config


startWorker = (config, path_to_worker) ->
  if path_to_worker? and path.existsSync path_to_worker
    if path_to_worker[0] == '.'
      path_to_worker = process.cwd() + '/' + path_to_worker[2..-1]
    
    process.env['_HIPPOGRIFF_SOCKET'] = config.socket
    worker = spawn "#{config.exec_binary}", ["#{path_to_worker}"], {cwd:path.dirname path_to_worker}
    worker.stdout.on 'data', (data) -> process.stdout.write data
    worker.stderr.on 'data', (data) -> process.stderr.write data
    worker.on 'exit', (code) ->
      if code? and code != 0
        startWorker(config, path_to_worker)
      else
        if Object.keys(workers).length == 0
          process.exit 0
    console.log "Started #{worker.pid}, as #{config.exec_binary} #{path_to_worker}"
    workers[worker.pid] = {
      status: "okay"
      handle: worker
      path_to_worker: path_to_worker
      config: config
      }


load_config_file = (defaults, path_to_config) ->
  config = defaults
  if path_to_config?
    file_config = JSON.parse fs.readFileSync(path_to_config).toString()
    for key, value of file_config
      config[key] = value
  config

exports.master './spec/worker/worker.coffee'