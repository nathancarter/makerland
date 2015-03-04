
# Settings Module

Loads the settings JSON data from the root folder if the game (not the
folder containing this module, but its parent) and exposes all that data to
anyone who imports this module, directly as module properties.

    fs = require 'fs'
    path = require 'path'
    settingsFile = path.join __dirname, '..', 'settings.json'

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
