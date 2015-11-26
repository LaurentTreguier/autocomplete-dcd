childProcess = require("child_process")
readline = require("readline")
types = require("./types")

module.exports =
  selector: ".source.d"
  disableForSelector: ".source.d .comment, .source.d .string"
  inclusionPriority: 1
  excludeLowerPriority: true
  server: null,

  startServer: ->
    @server = childProcess.spawn("dcd-server")

  stopServer: ->
    @server.kill()

  getPosition: (request) ->
    ed = request.editor
    coords = request.bufferPosition
    charPosition = 0
    i = 0

    while(i < coords.row)
      charPosition += ed.lineTextForBufferRow(i).length + 1
      ++i

    charPosition += coords.column

  getSuggestions: (request) ->
    completions = []
    @getCompletions(request.editor.getText(), @getPosition(request), completions)

  getCompletions: (text, position, completions) ->
    client = childProcess.spawn("dcd-client", ["-c" + position])
    reader = readline.createInterface(input: client.stdout)
    completionType = null

    reader.on("line", (line) =>
      switch completionType
        when "identifiers"
          parts = line.split("\t")
          comp = type: types[parts[1]]

          if comp.type == "function"
            comp.snippet = parts[0] + "($1)"
          else
            comp.text = parts[0]

          completions.push(comp)

        when "calltips"
          args = line.substr(line.indexOf("(") + 1, line.length - 2).split(", ")

          for i in [0 .. args.length - 1]
            args[i] = "${#{i + 1}:#{args[i]}}"

          completions.push(
            snippet: args.join(", ")
          )

        when null
          completionType = line
    )

    client.stdin.setEncoding("utf-8")
    client.stdin.write(text)
    client.stdin.end()

    new Promise((resolve) ->
      reader.on("close", ->
        resolve(completions)
      )
    )