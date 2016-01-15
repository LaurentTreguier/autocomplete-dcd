provider = require("./dcd-provider")

module.exports =
  config: require("./config")

  activate: ->
    provider.updateServerCommand()
    provider.updateClientCommand()
    provider.updateProtoThreshold()
    provider.observeConfig()

  deactivate: ->
    provider.stopServer()

  provide: -> provider
