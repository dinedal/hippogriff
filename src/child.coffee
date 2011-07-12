net = require 'net'
util = require 'util'
events = require('events')



Child = () ->
  events.EventEmitter.call(@)
  this.fly()

util.inherits Child, events.EventEmitter

Child.prototype.fly = () ->
  cntr = 0
  process.on "SIGQUIT",  () ->
  net.createServer((socket) =>
    @socket = socket
    socket.on 'data', (data) =>
      console.log "#{process.pid} - Got Data #{data.toString()}"
      data = data.toString()
      lines = data.split '\n'
      for line in lines
        if line == 'PING'
          if cntr == 0
            socket.write("PONG #{process.pid}" + '\n')
        if line == "GO AWAY #{process.pid}"
          console.log "okay"
          this.land()
  ).listen(process.env['_HIPPOGRIFF_SOCKET'])
  master_socket = new net.Socket()
  console.log process.env['_HIPPOGRIFF_MASTER_SOCKET']
  master_socket.connect process.env['_HIPPOGRIFF_MASTER_SOCKET'], () ->
    console.log "writing hello"
    master_socket.write "HELLO MY NAME IS #{process.pid}" + '\n'
    master_socket.end()


Child.prototype.land = () ->
  if @socket.writeable
    @socket.write("GOODBYE FROM #{process.pid}" + '\n')
    @socket.end()
  callback = (code) -> process.exit code
  this.emit "exit", callback
  


  



module.exports = Child