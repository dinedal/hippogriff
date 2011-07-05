Hippogriff
==========

Hippogriff is a process manager very much like Unicorn, except it uses *nix sockets to communicate with it's worker processes.

## Goals

- Support all Unicorn signals
- Support hosting multiple workers behind a single port
- Support logging as if all workers are a single process
- Support ZMQ programs as workers.

## Cake commands

`cake complie` to build the JS files from CoffeeScript

`cake spec` to run tests

