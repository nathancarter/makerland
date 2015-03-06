
# Settings Module

Loads the settings JSON data from the root folder if the game (not the
folder containing this module, but its parent) and exposes all that data to
anyone who imports this module, directly as module properties.

    fs = require 'fs'
    path = require 'path'
    module.exports.gameRoot = path.join __dirname, '..'
    settingsFile = path.join module.exports.gameRoot, 'settings.json'

## Getting the raw data

First, read the contents of the settings file.  Abort if we cannot do so.

    try
        stringdata = fs.readFileSync settingsFile
    catch e
        console.log 'Aborting game; cannot load settings:', e
        process.exit()

Second, interpret it as JSON.  If that fails, ignore its content entirely.

    try
        JSONdata = JSON.parse stringdata
    catch e
        console.log 'Ignoring settings file; invalid JSON:', e
        JSONdata = { }

Finally, install all those key-value pairs into this module.

    module.exports[key] = value for own key, value of JSONdata

## Convenience functions

It's often easier to have a function that queries the database for us, and
does some simple data cleaning or conversion for easier consumption by the
client.

For instance, if we're querying a path from the settings module, we'd like
it to be an absolute path.  The following function turns relative paths in
the settings file into absolute paths on the filesystem.

    module.exports.getPath = ( key ) ->
        throw 'No such setting key: ' + key if not module.exports[key]
        path.resolve module.exports.gameRoot, module.exports[key]

The following function is the same, except it returns a path relative to the
client subfolder of the repository, so the path is suitable to transmit to
the client, for its use in forming URLs to request data from the server.

    module.exports.clientPath = ( key ) ->
        absolute = module.exports.getPath key
        prefix = path.resolve module.exports.gameRoot, 'client'
        if absolute[...prefix.length] is prefix
            absolute[prefix.length..]
        else
            throw "Not a path in the client folder: #{absolute}"
