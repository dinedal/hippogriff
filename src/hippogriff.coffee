net = require 'net'
util = require 'util'
events = require('events')



Hippogriff = () ->
  events.EventEmitter.call(@)
  this.fly()

util.inherits Hippogriff, events.EventEmitter

Hippogriff.prototype.fly = () ->
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
  process.nextTick () ->
    master_socket = new net.Socket()
    console.log process.env['_HIPPOGRIFF_MASTER_SOCKET']
    master_socket.connect process.env['_HIPPOGRIFF_MASTER_SOCKET'], () ->
      console.log "writing hello"
      master_socket.write "HELLO MY NAME IS #{process.pid}" + '\n'
      master_socket.end()


Hippogriff.prototype.land = () ->
  self = @
  console.log "#{process.pid} - Landing! @socket.writable? #{util.inspect @socket.writable}"
  callback = (code) =>
    code ||= 0
    console.log "Callback called #{@socket.writable}"
    @socket.write("GOODBYE FROM #{process.pid}" + '\n') if @socket? and @socket.writable
    @socket.end()
    process.exit code
  this.emit "exit", callback
  
  


  



module.exports = Hippogriff