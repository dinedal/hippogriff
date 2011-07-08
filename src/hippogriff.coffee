fs = require 'fs'
util = require 'util'
path = require 'path'
net = require 'net'
{spawn} = require 'child_process'

# process.on 'uncaughtException', (err) ->
#   console.err 'Caught exception: ' + '\n' + util.inspect(err.stack, false, 6)

  
workers = {}
config = {}
socket_counter = 0

exports.master = (path_to_worker, path_to_config) ->
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
  
  
  # Start our engines....
  for i in [0...config.workers]
    startWorker config, path_to_worker
  
  # Monitoring of children
  monitorChildren = () ->
    setInterval (() ->
      new_workers = []
      for worker of workers
        console.log workers[worker].socket.destroyed
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
    # TBD
  
  quickshutdown = () ->
    forceWorkerShutdown () ->
      process.exit 0
  
  process.on 'SIGINT', quickshutdown
  process.on 'SIGTERM', quickshutdown
  
  process.on 'SIGQUIT', () ->
    console.log 'SIGQUIT - Asking workers to shutdown and then shutting down...'
    clearInterval(child_watcher_id)
    for worker of workers
      if workers[worker].socket?
        workers[worker].status = "quitting"
        # console.log workers[worker].socket.destroyed
        console.log workers[worker].socket.write("GO AWAY #{worker}" + '\n')
        # console.log util.inspect fs.statSync workers[worker].socket.server.path
        # fs.statSync
        buff = new Buffer "GO AWAY #{worker}" + '\n'
        # fs.writeSync workers[worker].socket.fd, buff, 0, buff.length, 1
        # process.nextTick(workers[worker].socket.write("GO AWAY #{worker}" + '\n'))
      else
        # No way to communicate
        workers[worker].handle.kill("SIGKILL")
        delete workers[worker]
    counter = 3
    # process.nextTick setInterval (() ->
    #   console.log counter
    #   counter--
    #   if counter == 0
    #     forceWorkerShutdown () ->
    #       process.exit -1
    #   else if Object.keys(workers).length == 0
    #     process.exit 0
    # ), config.checkInterval
  
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
    
    socket_counter++
    process.env['_HIPPOGRIFF_SOCKET'] = "/tmp/hippogriff.#{socket_counter}.sock"
    console.log "starting #{process.env['_HIPPOGRIFF_SOCKET']}"
    fs.unlinkSync process.env['_HIPPOGRIFF_SOCKET'] if path.existsSync process.env['_HIPPOGRIFF_SOCKET']
    # socket = new net.Socket()
    
    net.createServer((socket) ->
      socket.on 'data', (data) ->
        data = data.toString()
        console.log data
        lines = data.split '\n'
        for line in lines
          if line[0..4] == "PONG "
            workers[line[5..-1]].status = "okay"
          else if line[0..12] == "GOODBYE FROM "
            delete workers[line[13..-1]]
          else if line[0..16] == "HELLO MY NAME IS "
            workers[line[17..-1]].socket = socket
  
      socket.on 'error', (e) -> console.log util.inspect e
    ).listen process.env['_HIPPOGRIFF_SOCKET']
    
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