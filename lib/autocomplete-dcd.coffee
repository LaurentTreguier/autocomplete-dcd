provider = require './dcd-provider'

module.exports =
  activate: provider.startServer
  deactivate: provider.stopServer

  provide: ->
    provider