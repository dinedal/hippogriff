fs = require 'fs'
util = require 'util'
path = require 'path'
net = require 'net'
{spawn} = require 'child_process'
{argv} = require('optimist').usage('Usage: $0 [-config <JSON config object>]')

# process.on 'uncaughtException', (err) ->
#   console.err 'Caught exception: ' + '\n' + util.inspect(err.stack, false, 6)

  
workers = {}
config = {}
socket_counter = 0
new_master = null

exports.master = (path_to_worker, path_to_config) ->
  console.log "Master is #{process.pid}"
  # Set defaults
  if path.extname(path_to_worker) == '.coffee'
    config.exec_binary = 'coffee'
  else
    config.exec_binary = 'node'
  config.workers = 2
  config.socket = "/tmp/hippogriff.sock"
  config.checkInterval = 1000
  
  # Use user provided config for overrides
  config = load_config_file config, path_to_config
  config.path_to_config = path_to_config
  
  # Override all with command line config
  command_line_config = JSON.parse argv.config
  for key of command_line_config
    config[key] = command_line_config[key]
  
  # Start unix server for workers to report in
  net.createServer((socket) ->
    socket.on "data", (data) ->
      data = data.toString()
      console.log data
      lines = data.split '\n'
      for line in lines
        if line[0..16] == "HELLO MY NAME IS "
          worker_socket = new net.Socket()
          console.log workers[line[17..-1]].socket_path
          worker_socket.connect(workers[line[17..-1]].socket_path, () ->
            worker_socket.on 'data', (data) ->
              data = data.toString()
              console.log data
              lines = data.split '\n'
              for line in lines
                if line[0..4] == "PONG "
                  workers[line[5..-1]].status = "okay"
                else if line[0..12] == "GOODBYE FROM "
                  delete workers[line[13..-1]]
            socket.on 'error', (e) -> console.err util.inspect e
          )
          workers[line[17..-1]].socket = worker_socket
  ).listen(config.socket)
  
  # Start our engines....
  for i in [0...config.workers]
    startWorker config, path_to_worker
  
  # Monitoring of children
  monitorChildren = () ->
    setInterval (() ->
      if Object.keys(workers).length == 0
        process.exit 0
      new_workers = []
      for worker of workers
        if workers[worker].socket?
          if workers[worker].status == "concerned"
            console.log "Worker #{worker} failed to respond, SIGKILLing..."
            workers[worker].handle.kill("SIGKILL")
            new_workers.push workers[worker]
            delete workers[worker]
          else if workers[worker].status == "okay"
            workers[worker].socket.write 'PING\n' if workers[worker].socket?
            workers[worker].status = "concerned"
      for new_worker in new_workers
        startWorker(new_worker.config, new_worker.path_to_worker)
    ), config.checkInterval
  
  child_watcher_id = monitorChildren()
  
  forceWorkerShutdown = (callback) ->
    for worker of workers
      workers[worker].handle.kill("SIGKILL")
    callback()
  
  # Match Unicorn's signal handling
  process.on 'SIGHUP', () ->
    # Reload config, gracefully restart all workers
    # Set defaults
    if path.extname(path_to_worker) == '.coffee'
      config.exec_binary = 'coffee'
    else
      config.exec_binary = 'node'
    config.workers = 2
    config.socket = "/tmp/hippogriff.sock"
    config.checkInterval = 1000
    
    config = load_config_file config, config.path_to_config
    
  
  quickshutdown = () ->
    forceWorkerShutdown () ->
      process.exit 0
  
  process.on 'SIGINT', quickshutdown
  process.on 'SIGTERM', quickshutdown
  
  process.on 'SIGQUIT', () ->
    console.log 'SIGQUIT - Asking workers to shutdown and then shutting down...'
    clearInterval(child_watcher_id)
    for worker of workers
      initateGracefulExit worker, config
    counter = 3
    setInterval (() ->
      counter--
      if counter == 0
        forceWorkerShutdown () ->
          process.exit -1
      else if Object.keys(workers).length == 0
        process.exit 0
    ), config.checkInterval
  
  process.on 'SIGUSR1', () ->
    # Reopen all log files
    # TBD
  
  process.on 'SIGUSR2', () ->
    # Bring up a copy of this process and workers
    console.log 'Copying myself...'
    new_master = spawn "#{process.argv[0]}", ["#{process.argv[1]}", "--config '#{JSON.stringify config}'"], {cwd:process.cwd()}
    new_master.stdout.on 'data', (data) -> process.stdout.write data
    new_master.stderr.on 'data', (data) -> process.stderr.write data
    new_master.on 'exit', (code) -> process.exit code
    # Force graceful shutdown of all workers
    clearInterval(child_watcher_id)
    for worker of workers
      initateGracefulExit worker, config
    counter = 3
    setInterval (() ->
      counter--
      if counter == 0
        forceWorkerShutdown () ->
          workers = {}
    ), config.checkInterval
  
  process.on 'SIGWINCH', () ->
    console.log 'SIGWINCH - Asking workers to shutdown'
    for worker of workers
      initateGracefulExit worker, config
    
  process.on 'SIGTTIN', () ->
    # Increment worker count
    config.workers++
    startWorker config, path_to_worker
  
  process.on 'SIGTTOU', () ->
    # Decerment worker count
    config.workers--
    initateGracefulExit Object.keys(workers)[0], config
  
  process.on 'exit', (code, signal) ->
    console.log "Master died - #{code} #{signal}"
  
  config


initateGracefulExit = (worker, config) ->
  console.log "Quitting #{worker}"
  if workers[worker].socket?
    workers[worker].status = "quitting"
    workers[worker].socket.write("GO AWAY #{worker}" + '\n')
    workers[worker].socket.end()
  else
    # No way to communicate
    workers[worker].handle.kill("SIGKILL")
    delete workers[worker]
  counter = 3
  setInterval (() ->
    counter--
    if counter == 0 and workers[worker]?
      workers[worker].handle.kill("SIGKILL")
      delete workers[worker]
  ), config.checkInterval
  
  
startWorker = (config, path_to_worker) ->
  if path_to_worker? and path.existsSync path_to_worker
    if path_to_worker[0] == '.'
      path_to_worker = process.cwd() + '/' + path_to_worker[2..-1]
    
    socket_counter++
    process.env['_HIPPOGRIFF_SOCKET'] = "/tmp/hippogriff.#{socket_counter}.sock"
    process.env['_HIPPOGRIFF_MASTER_SOCKET'] = config.socket
    console.log "starting #{process.env['_HIPPOGRIFF_SOCKET']}"
    fs.unlinkSync process.env['_HIPPOGRIFF_SOCKET'] if path.existsSync process.env['_HIPPOGRIFF_SOCKET']
    
    worker = spawn "#{config.exec_binary}", ["#{path_to_worker}"], {cwd:path.dirname path_to_worker}
    worker.stdout.on 'data', (data) -> process.stdout.write data
    worker.stderr.on 'data', (data) -> process.stderr.write data
    worker.on 'exit', (code) ->
      if workers[worker.pid]? and workers[worker.pid].status != "quitting"
        delete workers[worker.pid]
        startWorker(config, path_to_worker)
    console.log "Started #{worker.pid}, as #{config.exec_binary} #{path_to_worker}"
    
    workers[worker.pid] = {
      status: "okay"
      handle: worker
      path_to_worker: path_to_worker
      config: config
      socket_path: process.env['_HIPPOGRIFF_SOCKET']
      }

load_config_file = (defaults, path_to_config) ->
  config = defaults
  if path_to_config?
    file_config = JSON.parse fs.readFileSync(path_to_config).toString()
    for key, value of file_config
      config[key] = value
  config

exports.master './spec/worker/worker.coffee'