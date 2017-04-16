module.exports =
  dmdConf:
    title: "Path to the dmd config file"
    description: "The command to execute to launch dub"
    type: "object"
    properties:
      darwin:
        title: "MacOS path"
        type: "string"
        default: "/usr/local/etc/dmd.conf"
      linux:
        title: "Linux path"
        type: "string"
        default: "/etc/dmd.conf"
      win32:
        title: "Windows path"
        type: "string"
        default: "C:\\D\\dmd2\\windows\\bin\\sc.ini"

  dub:
    title: "dub command"
    description: "The command to execute to launch dub"
    type: "string"
    default: "dub"

  dcdServer:
    title: "DCD server command"
    description: "The command to execute to launch the DCD server"
    type: "string"
    default: ""

  dcdClient:
    title: "DCD client command"
    description: "The command to execute to launch DCD clients"
    type: "string"
    default: ""

  protoThreshold:
    title: "Function prototype threshold"
    description: "If the number of functions showing in the suggestions is less or equal to this number, function prototypes will be shown (if set to -1 they will always show, but can have bad performance)"
    type: "integer"
    default: 10
    minimum: -1
