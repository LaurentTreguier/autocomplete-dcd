module.exports =
  dcdServer:
    title: "DCD server command"
    description: "The command to execute to launch the DCD server"
    type: "string"
    default: "dcd-server"

  dcdClient:
    title: "DCD client command"
    description: "The command to execute to launch DCD clients"
    type: "string"
    default: "dcd-client"

  dub:
    title: "dub client command"
    description: "The command to execute to launch dub"
    type: "string"
    default: "dub"

  protoThreshold:
    title: "Function prototype threshold"
    description: "If the number of functions showing in the suggestions is less or equal to this number, function prototypes will be shown (if set to -1 they will always show, but can have bad performance)"
    type: "integer"
    default: 10
    minimum: -1
