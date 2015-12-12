childProcess = require("child_process")
readline = require("readline")
fs = require("fs")
types = require("./types")

module.exports =
  selector: ".source.d"
  disableForSelector: ".source.d .comment, .source.d .string"
  inclusionPriority: 1
  excludeLowerPriority: true

  startServer: ->
    @getDubImports().then((imports) ->
      for i in [0 .. imports.length - 1]
        imports[i] = "-I" + imports[i]

      childProcess.spawn("dcd-server", imports, stdio: "ignore")
    )

  stopServer: ->
    childProcess.spawn("dcd-client", ["--shutdown"])

  getDubImports: ->
    dub = childProcess.spawn("dub", ["list"])
    reader = readline.createInterface(input: dub.stdout)
    packages = {}
    firstLine = true
    imports = []

    reader.on("line", (line) ->
      if firstLine
        firstLine = false
      else if line.length
        p = line.substring(0, line.lastIndexOf(":")).trim()
        i = p.substring(0, p.lastIndexOf(" "))
        res = line.substring(line.indexOf("/"))

        if not packages[i] or packages[i] < res
          packages[i] = res
    )

    new Promise((resolve) ->
      reader.on("close", ->
        for name of packages
          p = packages[name]
          dubFile = p + "dub.json"

          try
            fs.accessSync(dubFile, fs.R_OK)

            dub = require(dubFile)
            dub.sourcePaths ?= ["source", "src"]

            for path in dub.sourcePaths
              imports.push(p + path)
          catch err

        resolve(imports)
      )
    )

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