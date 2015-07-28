
# Main script run when Electron app launches

This is thrown together now and mostly experimental.  It doesn't do much,
and is poorly documented.  Try back later.

    app = require 'app'
    BrowserWindow = require 'browser-window'
    ipc = require 'ipc'
    fs = require 'fs'
    path = require 'path'
    # require( 'crash-reporter' ).start()

And even though the following may seem out-of-place in a CoffeeScript file,
it's necessary for launching CoffeeScript-based modules as child processes.

    require 'coffee-script/register'

If the player does not have a universes folder yet, create one.

    myUniversesFolder = path.join app.getPath( 'userData' ), 'universes'
    try
        fs.mkdirSync myUniversesFolder
    catch e
        if e.code isnt 'EEXIST'
            console.log "My Universes folder does not exist, and could not
                create it.  Error when trying to create: #{e}"
            process.exit 1

Load all my universes.

    myUniverses = { }
    for universe in fs.readdirSync myUniversesFolder
        fullpath = path.join myUniversesFolder, universe
        if not fs.statSync( fullpath ).isDirectory() then continue
        myUniverses[universe] =
            state : 'closed'

Keep a global reference of the window object, so the window won't be closed
automatically when the JavaScript object is GCed.

    mainWindow = null

Quit when all windows are closed. On OS X it is common for applications and
their menu bar to stay active until the user quits explicitly with Cmd + Q

    app.on 'window-all-closed', ->
        if process.platform isnt 'darwin' then app.quit()

This method will be called when Electron has finished initialization and is
ready to create browser windows.

    app.on 'ready', ->

Create the browser window.

        mainWindow = new BrowserWindow { width: 1024, height: 768 }

Refresh its content

        mainWindow.loadUrl "file://#{__dirname}/index.html"
        mainWindow.webContents.on 'did-finish-load', updateUniverseLists
        # mainWindow.openDevTools()

Emitted when the window is closed. Dereference the window object, usually
you would store windows in an array if your app supports multi windows, this
is the time when you should delete the corresponding element.

        mainWindow.on 'closed', ->
            mainWindow = null

Auxiliary routine used above.

    updateUniverseLists = ->
        if not mainWindow? then return
        mainWindow.webContents.send 'clearColumn', true
        for own name, data of myUniverses
            mainWindow.webContents.send 'addUniverse', true, name,
                data.state
        mainWindow.webContents.send 'clearColumn', false
        mainWindow.webContents.send 'addMessage', false,
            '<h4>No other universes nearby</h4>
             <p>To see other universes,<br>have a friend run MakerLand
             <br>and open a universe for you to visit.</p>'

Listen for buttons clicked in windows we spawn.

    ipc.on 'clicked button', ( event, arg ) ->
        if arg is 'quit' then app.quit()
    ipc.on 'universe state set', ( event, data ) ->
        if myUniverses.hasOwnProperty data.name
            previous = myUniverses[data.name].state
            myUniverses[data.name].state = data.state
            if previous is 'closed' and data.state isnt 'closed'
                myUniverses[data.name].server = startServer data.name
            if data.state is 'open-to-me'
                myUniverses[data.name].server.stdin.write \
                    'localConnectionsOnly=yes\n'
            if data.state is 'open-to-all'
                myUniverses[data.name].server.stdin.write \
                    'localConnectionsOnly=no\n'
            updateUniverseLists()

Auxiliary routine for spawning game servers.

    startServer = ( folderName ) ->
        fullUniversePath = path.join myUniversesFolder, folderName

First, update the server settings to use a port we're not already using.

        settingsFile = path.join fullUniversePath, 'settings.json'
        settings = JSON.parse fs.readFileSync settingsFile
        usedPorts = [ ]
        for own name, data of myUniverses
            if data.server then usedPorts.push data.server.port
        settings.port = 9900
        while settings.port in usedPorts then settings.port++
        fs.writeFileSync settingsFile, JSON.stringify settings, null, 4

Second, fire up the child process.

        server =
            path.resolve path.join __dirname, 'server', 'server.litcoffee'
        console.log "Starting universe stored at #{fullUniversePath}..."
        child = require( 'child_process' ).fork server,
            cwd : fullUniversePath
            silent : yes
        if child
            child.stdout.on 'data', ( data ) ->
                console.log "#{folderName} STDOUT:\n#{data}"
            child.stderr.on 'data', ( data ) ->
                console.log "#{folderName} STDERR:\n#{data}"
            child.on 'close', ( code ) ->
                console.log "#{folderName} exited with code #{code}"
            console.log "#{folderName} child process ID is #{child.pid}"
        else
            console.log "#{folderName} child process is null; fork failed"

Store the port in it and return it.

        child.port = settings.port
        child

When quitting, kill child processes.

    app.on 'quit', ->
        for own name, data of myUniverses
            if data.state isnt 'closed' and data.server?
                console.log "Killing server for universe #{data.name}
                    (process ID #{data.server.pid})..."
                process.kill data.server.pid, 'SIGINT'
