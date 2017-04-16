provider = require("./dcd-provider")

module.exports =
  config: require("./config")

  activate: ->
    provider.installDcd()

  deactivate: ->
    provider.stopServer()

  provide: ->
    provider
