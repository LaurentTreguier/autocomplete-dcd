# DCD Autocomplete Package

Autocomplete provider for the D language using the [D Completion Daemon](https://github.com/Hackerpilot/DCD).

## Prerequisites

__Dub must be installed on your system for the extension to work.__

DCD can either be installed manually or automatically by the extension (using dub).
The `dcd-server` and `dcd-client` launching commands can either be in your `PATH` and thus set as commands (for example `dcd-server` and `dcd-client`), or explicit full paths to the executables (for example `/usr/bin/dcd-server` and `/usr/bin/dcd-client`).

## Usage

- Install DCD (optional)
- Open a D source file
- Use `ctrl + space` to complete a symbol, package name or function arguments when placing the cursor right after the opening parenthesis

## TODO

- Function documentation display
