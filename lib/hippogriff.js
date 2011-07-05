(function() {
  var async, fs, path, spawn, util;
  fs = require('fs');
  util = require('util');
  path = require('path');
  spawn = require('child_process').spawn;
  async = require('async');
  process.on('uncaughtException', function(err) {
    return console.log('Caught exception: ' + '\n' + util.inspect(err.stack, false, 6));
  });
  exports.master = function(path_to_worker, path_to_config) {
    var config, file_config, key, value, worker, workers;
    config = {};
    workers = [];
    if (path.extname(path_to_worker) === '.coffee') {
      config.exec_binary = 'coffee';
    } else {
      config.exec_binary = 'node';
    }
    config.workers = 1;
    if (path_to_config != null) {
      file_config = JSON.parse(fs.readFileSync(path_to_config).toString());
      for (key in file_config) {
        value = file_config[key];
        config[key] = value;
      }
    }
    console.log(util.inspect(path_to_worker));
    if ((path_to_worker != null) && path.existsSync(path_to_worker)) {
      if (path_to_worker[0] === '.') {
        path_to_worker = process.cwd() + '/' + path_to_worker.slice(2);
      }
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
        return process.exit(code);
      });
      workers.push(worker);
    }
    if (workers.length > 0) {
      setInterval((function() {
        return console.log("testing");
      }), 1000);
    }
    return config;
  };
}).call(this);
