childProcess = require("child_process")
readline = require("readline")
fs = require("fs")
path = require("path")
types = require("./types")

packageName = "autocomplete-dcd"

module.exports =
  selector: ".source.d"
  disableForSelector: ".source.d .comment, .source.d .string"
  inclusionPriority: 1
  excludeLowerPriority: true
  serverCommand: "dcd-server"
  clientCommand: "dcd-client"

  parseCommand: (line) ->
    words = line.split(" ")

    prog: words[0]
    args: words.slice(1)

  startServer: ->
    atom.notifications.addInfo("Starting DCD server")
    Promise.all([@getDmdImports(), @getDubImports()])
      .then((importsResults) -> importsResults.reduce((a, b) -> a.concat(b)))
      .then((imports) =>
        command = @parseCommand(atom.config.get(packageName + ".dcdServer") or @serverCommand)
        childProcess.spawn(command.prog, command.args.concat(imports), stdio: "ignore")
      )

  stopServer: ->
    command = @parseCommand(atom.config.get(packageName + ".dcdClient") or @clientCommand)
    command.args.push("--shutdown")
    childProcess.spawn(command.prog, command.args)

  installDcd: ->
    command = @parseCommand(atom.config.get(packageName + ".dub"))

    new Promise((resolve) ->
      search = childProcess.spawn(command.prog, command.args.concat(["search", "dcd"]))
      reader = readline.createInterface(input: search.stdout)

      reader.on("line", (line) =>
        match = line.match(/dcd\s+\((\S+)\)/)
        if match then resolve(match[1])
      )
    ).then((version) -> new Promise((resolve) ->
      childProcess.spawn(command.prog, command.args.concat(["fetch", "dcd", "--version", version]))
        .on("exit", resolve)
    )).then(=> new Promise((resolve) =>
      list = childProcess.spawn(command.prog, command.args.concat(["list"]))
      reader = readline.createInterface(input: list.stdout)
      version = ""
      dubPath = ""

      reader.on("line", (line) =>
        match = line.match(/\s*dcd\s+(\S+?):\s+(.+)/)

        if match and not (match[1] is "~master") and (match[1] > version)
          version = match[1]
          dubPath = match[2]
          @serverCommand = path.join(dubPath, "dcd-server")
          @clientCommand = path.join(dubPath, "dcd-client")
      )

      reader.on("close", -> resolve(dubPath))
    )).then((dubPath) => new Promise((resolve) =>
      try
        fs.accessSync(@serverCommand, fs.R_OK)
      catch error
        atom.notifications.addInfo("Building DCD server")
        childProcess.spawn(command.prog, command.args.concat(["build", "--build", "release", "--config", "server"]), cwd: dubPath)
          .on("exit", (code) ->
            if not code
              atom.notifications.addSuccess("Built DCD server")
              resolve(dubPath)
          )
    )).then((dubPath) => new Promise((resolve) =>
      try
        fs.accessSync(@clientCommand)
      catch error
        atom.notifications.addInfo("Building DCD client")
        childProcess.spawn(command.prog, command.args.concat(["build", "--build", "release", "--config", "client"]), cwd: dubPath)
          .on("exit", (code) ->
            if not code
              atom.notifications.addSuccess("Built DCD client")
              resolve()
          )
    ))

  getDmdImports: ->
    new Promise((resolve) ->
      fs.readFile(atom.config.get(packageName + ".dmdConf." + process.platform), (err, data) ->
        if not err
          resolve(data.toString().match(/-I\S+/g))
    ))

  getDubImports: ->
    command = @parseCommand(atom.config.get(packageName + ".dub"))
    command.args.push("list")
    dub = childProcess.spawn(command.prog, command.args)
    reader = readline.createInterface(input: dub.stdout)
    packages = {}
    firstLine = true
    imports = []

    for path in atom.project.getPaths()
      for dubExt in ["json", "sdl"]
        try
          fs.accessSync(path + "/dub.#{dubExt}", fs.R_OK)
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

        resolve(imports.map((i) -> "-I" + i))
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
    command = @parseCommand(atom.config.get(packageName + ".dcdClient") or @clientCommand)
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

    client.stdin.end(text, "ascii")

    new Promise((resolve) =>
      reader.on("close", =>
        promises = []
        protoThreshold = atom.config.get(packageName + ".protoThreshold")

        if protoThreshold < 0 or functions.length <= protoThreshold
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
