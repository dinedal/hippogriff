(function() {
  var config, fs, load_config_file, net, path, spawn, startWorker, util, workers;
  fs = require('fs');
  util = require('util');
  path = require('path');
  net = require('net');
  spawn = require('child_process').spawn;
  process.on('uncaughtException', function(err) {
    return console.err('Caught exception: ' + '\n' + util.inspect(err.stack, false, 6));
  });
  workers = {};
  config = {};
  exports.master = function(path_to_worker, path_to_config) {
    var quickshutdown, server, socket;
    if (path.extname(path_to_worker) === '.coffee') {
      config.exec_binary = 'coffee';
    } else {
      config.exec_binary = 'node';
    }
    config.workers = 1;
    config.socket = "/tmp/hippogriff.sock";
    config.checkInterval = 1000;
    config = load_config_file(config, path_to_config);
    socket = null;
    server = net.createServer(function(c) {
      c.on('data', function(data) {
        data = data.toString();
        if (data.slice(0, 5) === "PONG ") {
          return workers[data.slice(5, -1)].status = "okay";
        } else if (data.slice(0, 14) === "GOODBYE FROM ") {
          return delete workers[data.slice(13, -1)];
        }
      });
      return socket = c;
    });
    server.listen(config.socket, function() {
      var i, _ref, _results;
      _results = [];
      for (i = 0, _ref = config.workers; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        _results.push(startWorker(config, path_to_worker));
      }
      return _results;
    });
    setInterval((function() {
      var new_worker, new_workers, worker, _i, _len, _results;
      new_workers = [];
      for (worker in workers) {
        console.log(util.inspect(workers[worker].status));
        if (workers[worker].status === "concerned") {
          console.log("Worker " + worker + " failed to respond, SIGKILLing...");
          workers[worker].handle.kill("SIGKILL");
          new_workers.push(workers[worker]);
          delete workers[worker];
        }
      }
      socket.write('PING\n');
      for (worker in workers) {
        workers[worker].status = "concerned";
      }
      _results = [];
      for (_i = 0, _len = new_workers.length; _i < _len; _i++) {
        new_worker = new_workers[_i];
        _results.push(startWorker(new_worker.config, new_worker.path_to_worker));
      }
      return _results;
    }), config.checkInterval);
    process.on('SIGHUP', function() {});
    quickshutdown = function() {
      var worker;
      for (worker in workers) {
        workers[worker].handle.kill("SIGKILL");
      }
      return process.exit(0);
    };
    process.on('SIGINT', quickshutdown);
    process.on('SIGTERM', quickshutdown);
    process.on('SIGQUIT', function() {});
    process.on('SIGUSR1', function() {});
    process.on('SIGUSR2', function() {});
    process.on('SIGWINCH', function() {});
    process.on('SIGTTIN', function() {
      config.workers++;
      return startWorker(config, path_to_worker);
    });
    process.on('SIGTTOU', function() {
      config.workers--;
      workers[Object.keys(workers)[0]].handle.kill("SIGKILL");
      return delete workers[worker];
    });
    return config;
  };
  startWorker = function(config, path_to_worker) {
    var worker;
    if ((path_to_worker != null) && path.existsSync(path_to_worker)) {
      if (path_to_worker[0] === '.') {
        path_to_worker = process.cwd() + '/' + path_to_worker.slice(2);
      }
      process.env['_HIPPOGRIFF_SOCKET'] = config.socket;
      worker = spawn("" + config.exec_binary, ["" + path_to_worker], {
        cwd: path.dirname(path_to_worker)
      });
      worker.stdout.on('data', function(data) {
        return process.stdout.write(data);
      });
      worker.stderr.on('data', function(data) {
        return process.stderr.write(data);
      });
      worker.on('exit', function(code) {
        if ((code != null) && code !== 0) {
          return startWorker(config, path_to_worker);
        } else {
          if (Object.keys(workers).length === 0) {
            return process.exit(0);
          }
        }
      });
      console.log("Started " + worker.pid + ", as " + config.exec_binary + " " + path_to_worker);
      return workers[worker.pid] = {
        status: "okay",
        handle: worker,
        path_to_worker: path_to_worker,
        config: config
      };
    }
  };
  load_config_file = function(defaults, path_to_config) {
    var file_config, key, value;
    config = defaults;
    if (path_to_config != null) {
      file_config = JSON.parse(fs.readFileSync(path_to_config).toString());
      for (key in file_config) {
        value = file_config[key];
        config[key] = value;
      }
    }
    return config;
  };
  exports.master('./spec/worker/worker.coffee');
}).call(this);
