# Changelog

## 1.0.0 - First Release
* Every feature added
* Every bug fixed

## 1.0.1
* Fixed function completion
* Added tasks to README
* Fixed License

## 1.0.2
* Added package usage and more tasks to README

## 1.1.0
* Changed function completion to provide the complete prototypes of functions
* Fixed server stderr buffer filling up and making the plugin stopping to work

## 1.1.1
* (Possibly) improve performance

## 1.1.2
* Fix server variable assigned to wrong object

## 1.1.3
* Fix DCD server being killed when closing a window and possibly leaving other atom windows without a server to get completion from

## 1.2.0
* Added partial dub support (dub.sdl files are not supported for now)

## 1.2.1
* The DCD server doesn't start at Atom startup anymore to prevent unnecessary memory consumption when not editing D language files

## 1.3.0
* The DCD server now also add the current project's roots directories to the server's import list if they are dub projects