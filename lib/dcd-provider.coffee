childProcess = require("child_process")
readline = require("readline")
types = require("./types")

module.exports =
  selector: ".source.d"
  disableForSelector: ".source.d .comment, .source.d .string"
  inclusionPriority: 1
  excludeLowerPriority: true

  startServer: ->
    childProcess.spawn("dcd-server", stdio: ["ignore", "ignore", "ignore"])

  stopServer: ->
    childProcess.spawn("dcd-client", ["--shutdown"])

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

  getCompletions: (text, position, completions, funcName) ->
    client = childProcess.spawn("dcd-client", ["-c" + position])
    reader = readline.createInterface(input: client.stdout)
    completionType = null
    promises = []
    fakeContext = null

    reader.on("line", (line) =>
      parts = line.split("\t")

      switch completionType
        when "identifiers"
          if types[parts[1]] == "function"
            if fakeContext == null
              fakeContext = @createFunctionContext(text)

            fakeText = fakeContext + parts[0] + "("
            promises.push(@getCompletions(fakeText, fakeText.length, completions, parts[0]))
          else
            completions.push(
              text: parts[0]
              type: types[parts[1]]
            )

        when "calltips"
          args = line.substring(line.lastIndexOf("(") + 1, line.length - 1).split(", ")

          for i in [0 .. args.length - 1]
            args[i] = "${#{i + 1}:#{args[i]}}"

          comp =
            snippet: if funcName then funcName + "(" + args.join(", ") + ")$" + args.length + 1 else args.join(", ")
            type: if funcName then "function" else "snippet"

          if funcName
            comp.leftLabel = line.substring(0, line.indexOf(" "))

          completions.push(comp)

        when null
          completionType = line
    )

    client.on("exit", (code) =>
      if code
        @startServer()
    )

    client.stdin.setEncoding("utf-8")
    client.stdin.write(text)
    client.stdin.end()

    new Promise((resolve) ->
      reader.on("close", ->
        Promise.all(promises).then((-> resolve(completions)), resolve)
      )
    )

  createFunctionContext: (text) ->
    fakeText = ""
    reg = /import [^;]+;/g

    while (res = reg.exec(text)) != null
      fakeText += res[0]