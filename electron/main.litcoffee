
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

The function for loading all the user's universes.  It's called from the
`updateUniverseLists` function, below.

    myUniverses = { }
    loadUniverses = ->
        newObject = { }
        for universe in fs.readdirSync myUniversesFolder
            fullpath = path.join myUniversesFolder, universe
            if not fs.statSync( fullpath ).isDirectory() then continue
            newObject[universe] = myUniverses[universe] ? state : 'closed'
        myUniverses = newObject

We will do a similar thing for nearby universes, using mDNS, below.  But we
must declare the global variable here, so that it is visible throughout this
module.

    nearbyUniverses = { }

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
        loadUniverses()
        mainWindow.webContents.send 'clearColumn', true
        numUniverses = 0
        for own name, data of myUniverses
            if data.state is 'closed' or not data.server
                data.numPlayers = 0
            data.numPlayers ?= 0
            mainWindow.webContents.send 'addMyUniverse',
                name : name
                numPlayers : data.numPlayers
                state : data.state
                internalIP : data.internalIP
                externalIP : data.externalIP
            numUniverses++
        if numUniverses is 0
            mainWindow.webContents.send 'addMessage', true,
                '<h4>You have no universes.</h4>
                 <p>You must have deleted even the sample universe (!).</p>
                 <p>To create a new one, use the button below.</p>'
        mainWindow.webContents.send 'clearColumn', false
        numUniverses = 0
        for own name, data of nearbyUniverses
            mainWindow.webContents.send 'addOtherUniverse',
                name : name
                externalIP : data.address
                port : data.port
            numUniverses++
        if numUniverses is 0
            mainWindow.webContents.send 'addMessage', false,
                '<h4>No other universes nearby</h4>
                 <p>To see other universes,
                 <br>have a friend on your network run MakerLand
                 <br>and open a universe for you to visit.</p>'

We want to listen for Multicast DNS MakerLand advertisements nearby.

To do so, we must first know what our own IP addresses are, so that we can
distinguish which mDNS responses come from our own machine vs. other
machines.

    myIPs = [ ]
    for own name, list of require( 'os' ).networkInterfaces()
        myIPs.push iface.address for iface in list

Now listen for mDNS events.

    mdns = require 'mdns'
    mdnsBrowser = mdns.createBrowser mdns.tcp 'makerland'
    mdnsBrowser.on 'serviceUp', ( service ) ->
        ipv4s = ( address for address in service.addresses \
            when /\d+\.\d+\.\d+\.\d+/.test address )
        if ipv4s.length is 0 then return
        ipv4 = ipv4s.shift()
        if ipv4 in myIPs then return
        name = service.txtRecord.name
        nearbyUniverses[name] =
            address : ipv4
            port : service.port
            hostname : service.name # bad as a unique ID, but what else??
        updateUniverseLists()
    mdnsBrowser.on 'serviceDown', ( service ) ->
        for own name, data of nearbyUniverses
            if data.hostname is service.name
                delete nearbyUniverses[name]
                break
        updateUniverseLists()
    mdnsBrowser.start()

Listen for buttons clicked in windows we spawn.

    ipc.on 'clicked button', ( event, arg ) ->
        if arg is 'quit' then app.quit()
    ipc.on 'universe state set', ( event, data ) ->
        if myUniverses.hasOwnProperty data.name
            previous = myUniverses[data.name].state
            if previous is 'closed' and data.state isnt 'closed'
                myUniverses[data.name].server = startServer data.name
            if data.state is 'open-to-me'
                myUniverses[data.name].server.stdin.write \
                    'localConnectionsOnly=yes\n'
            if data.state is 'open-to-all'
                myUniverses[data.name].server.stdin.write \
                    'localConnectionsOnly=no\n'
            if previous isnt 'closed' and data.state is 'closed'
                stopServer data.name
            myUniverses[data.name].state = data.state
            updateUniverseLists()
    ipc.on 'visit my universe', ( event, data ) ->
        if not universe = myUniverses[data] then return
        require( 'shell' ).openExternal \
            "http://localhost:#{universe.server.port}"
    ipc.on 'visit other universe', ( event, data ) ->
        if not universe = nearbyUniverses[data] then return
        require( 'shell' ).openExternal \
            "http://#{universe.address}:#{universe.port}"
    ipc.on 'universe action', ( event, data ) ->
        switch data.action
            when 'copy'
                makeName = ( i ) ->
                    name = data.name
                    while match = /^copy (?:[0-9]+ )?of /i.exec name
                        name = name[match[0].length..]
                    if i is 1 then "Copy of #{name}" \
                    else "Copy #{i} of #{name}"
                folder = ( name ) -> path.join myUniversesFolder, name
                name = makeName i = 1
                while fs.existsSync folder name then name = makeName ++i
                ncp = require( 'ncp' ).ncp
                ncp folder( data.name ), folder( name ), ( err ) ->
                    if err
                        require( 'dialog' ).showMessageBox mainWindow,
                            type : 'error'
                            buttons : [ 'OK' ]
                            title : 'Renaming error'
                            message : 'An error was encountered, and the
                                copy was not performed.'
                    else
                        updateUniverseLists()
            when 'rename'
                fs.rename path.join( myUniversesFolder, data.name ),
                    path.join( myUniversesFolder, data.value ), ( err ) ->
                        if err
                            require( 'dialog' ).showMessageBox mainWindow,
                                type : 'error'
                                buttons : [ 'OK' ]
                                title : 'Renaming error'
                                message : 'An error was encountered, and the
                                    renaming was not performed.  Perhaps you
                                    chose an invalid name, and should try
                                    another.'
                        else
                            updateUniverseLists()
            when 'delete'
                folder = path.join myUniversesFolder, data.name
                require( 'rimraf' ) folder, ( err ) ->
                    if err
                        require( 'dialog' ).showMessageBox mainWindow,
                            type : 'error'
                            buttons : [ 'OK' ]
                            title : 'Renaming error'
                            message : 'An error was encountered, and the
                                deletion was not performed.'
                    else
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
                needsUpdate = no
                if match = /there are now ([0-9]+) players/.exec data
                    myUniverses[folderName].numPlayers = match[1]
                    needsUpdate = yes
                re = /Internal users connect here:\s*(http:\/\/[0-9.:]+)/
                if match = re.exec data
                    myUniverses[folderName].internalIP = match[1]
                    needsUpdate = yes
                re = /External users connect here:\s*(http:\/\/[0-9.:]+)/
                if match = re.exec data
                    myUniverses[folderName].externalIP = match[1]
                    needsUpdate = yes
                if needsUpdate then updateUniverseLists()
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

There is a corresponding function for stopping a server.

    stopServer = ( folderName ) ->
        console.log "Attempting to stop universe #{folderName}..."
        if not ( data = myUniverses[folderName] )?
            console.log '\tNo universe with that name!'
            return no
        delete data.internalIP
        delete data.externalIP
        if data.state is 'closed' or not data.server?
            delete data.server
            console.log '\tThat universe\'s server is not running!'
            return no
        console.log "\tKilling server for universe #{folderName}
            (process ID #{data.server.pid})..."
        process.kill data.server.pid, 'SIGINT'
        delete data.server
        return yes

When quitting, kill child processes.

    app.on 'quit', -> stopServer universe for own universe of myUniverses
