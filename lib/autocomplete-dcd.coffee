provider = require './dcd-provider'

module.exports =
  deactivate: ->
    provider.stopServer()

  provide: ->
    provider