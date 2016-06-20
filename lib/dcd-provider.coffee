childProcess = require("child_process")
readline = require("readline")
fs = require("fs")
types = require("./types")

packageName = "autocomplete-dcd"

module.exports =
  selector: ".source.d"
  disableForSelector: ".source.d .comment, .source.d .string"
  inclusionPriority: 1
  excludeLowerPriority: true

  updateServerCommand: ->
    @serverCommand = atom.config.get(packageName + ".dcdServer")

  updateClientCommand: ->
    @clientCommand = atom.config.get(packageName + ".dcdClient")

  updateDubCommand: ->
    @dubCommand = atom.config.get(packagename + ".dub")

  updateProtoThreshold: ->
    @protoThreshold = atom.config.get(packageName + ".protoThreshold")

  observeConfig: ->
    atom.config.onDidChange(packageName + ".dcdServer", => @updateServerCommand())
    atom.config.onDidChange(packageName + ".dcdClient", => @updateClientCommand())
    atom.config.onDidChange(packageName + ".dub", => @updateDubCommand())
    atom.config.onDidChange(packageName + ".protoThreshold", => @updateProtoThreshold())

  parseCommand: (line) ->
    words = line.split(" ")

    prog: words[0]
    args: words.slice(1)

  startServer: ->
    @getDubImports().then((imports) =>
      for i in [0 .. imports.length - 1]
        imports[i] = "-I" + imports[i]

      command = @parseCommand(@serverCommand)
      childProcess.spawn(command.prog, command.args.concat(imports), stdio: "ignore")
    )

  stopServer: ->
    command = @parseCommand(@clientCommand)
    command.args.push("--shutdown")
    childProcess.spawn(command.prog, command.args)

  getDubImports: ->
    command = @parseCommand(@dubCommand)
    command.args.push("list")
    dub = childProcess.spawn(command.prog, command.args)
    reader = readline.createInterface(input: dub.stdout)
    packages = {}
    firstLine = true
    imports = []

    for path in atom.project.getPaths()
      for dubExt in ["json", "sdl"]
        try
          fs.accessSync(path + "/dub.#{dubExt}")
          name = path.slice(path.lastIndexOf("/") + 1)
          packages[name] = path + "/"
        catch err

    reader.on("line", (line) ->
      if firstLine
        firstLine = false
      else if line.length
        p = line.slice(0, line.lastIndexOf(":")).trim()
        i = p.slice(0, p.lastIndexOf(" "))
        res = line.slice(line.lastIndexOf(":") + 2)

        if not packages[i] or packages[i] < res
          packages[i] = res
    )

    new Promise((resolve) =>
      reader.on("close", =>
        for name of packages
          p = packages[name]

          for dubExt in ["json", "sdl"]
            dubFile = p + "dub.#{dubExt}"

            try
              fs.accessSync(dubFile, fs.R_OK)

              if dubExt is "json"
                dub = require(dubFile)
              else
                dub = sourcePaths: @getSourcePaths(fs.readFileSync(dubFile))

              dub.sourcePaths ?= ["source", "src"]

              for path in dub.sourcePaths
                imports.push(p + path)
            catch err

        resolve(imports)
      )
    )

  getSourcePaths: (data) ->
    res = /^sourcePaths.*$/gm.exec(data)

    if res then res[0].replace(/"/g, "").split(" ").slice(1) else undefined

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
    @request = request
    completions = []
    @getCompletions(request.editor.getText(), @getPosition(request), completions)

  getCompletions: (text, position, completions, funcName) ->
    command = @parseCommand(@clientCommand)
    command.args.push("-c" + position)
    client = childProcess.spawn(command.prog, command.args)
    reader = readline.createInterface(input: client.stdout)
    completionType = null
    functions = []

    reader.on("line", (line) ->
      parts = line.split("\t")

      switch completionType
        when "identifiers"
          if types[parts[1]] is "function"
            functions.push(parts[0])
          else
            completions.push(
              text: parts[0]
              type: types[parts[1]]
            )

        when "calltips"
          template = line.match(/[^)]*\)\s*\(/)
          start = template[0].length - 1 if template
          args = line.slice(line.indexOf("(", start) + 1, line.length - 1).split(", ")

          for i in [0 .. args.length - 1]
            args[i] = "${#{i + 1}:#{args[i]}}"

          comp =
            snippet: if funcName then funcName + "(" + args.join(", ") + ")$" + args.length + 1 else args.join(", ")
            type: if funcName then "function" else "snippet"

          if funcName
            ret = line.slice(0, line.indexOf(" "))

            comp.leftLabel = if ret.startsWith(funcName) then "auto" else ret

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

    new Promise((resolve) =>
      reader.on("close", =>
        promises = []

        if @protoThreshold < 0 or functions.length <= (@protoThreshold)
          for f in functions
            fakeText = [
              text.slice(0, position - @request.prefix.length)
              f
              "("
              text.slice(position)
            ].join("")

            promises.push(
              @getCompletions(fakeText, position - @request.prefix.length + f.length + 1, completions, f)
            )
        else
          for f in functions
            completions.push(
              snippet: f + "($1)"
              type: "function"
            )

        Promise.all(promises).then((-> resolve(completions)), resolve)
      )
    )
