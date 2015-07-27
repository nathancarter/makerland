
# Main script run when Electron app launches

This is thrown together now and mostly experimental.  It doesn't do much,
and is poorly documented.  Try back later.

    app = require 'app'
    BrowserWindow = require 'browser-window'
    ipc = require 'ipc'
    # require( 'crash-reporter' ).start()

Load all my universes.

    myUniverses =
        'my test 1' :
            state : 'closed'

Be able to spawn child processes

    # process.env[(process.platform == 'win32') ? 'USERPROFILE' : 'HOME']

    ###
    require( 'coffee-script/register' );
    var path = require( 'path' );
    var child = require( 'child_process' ).fork( 'server/server.litcoffee', {
        cwd : process.cwd(),
        silent : true
    } );
    if ( child ) {
        child.stdout.on( 'data', function ( data ) {
          console.log( 'child process STDOUT:\n' + data );
        } );
        child.stderr.on( 'data', function ( data ) {
          console.log( 'child process STDERR:\n' + data );
        } );
        child.on( 'close', function ( code ) {
          console.log( 'child process exited with code ' + code );
        } );
        console.log( 'child pid is ' + child.pid );
    } else {
        console.log( 'child was null!!' );
    }
    ###

Keep a global reference of the window object, so the window won't be closed
automatically when the JavaScript object is GCed.

    mainWindow = null

Quit when all windows are closed. On OS X it is common for applications and
their menu bar to stay active until the user quits explicitly with Cmd + Q

    app.on 'window-all-closed', ->
        if process.platform isnt 'darwin' then app.quit()

When quitting, kill child process

    ###
    app.on( 'quit', function () {
        console.log( 'killing makerland process ' + child.pid + '...' );
        process.kill(child.pid, 'SIGINT');
        console.log( 'done killing.' );
    } );
    ###

This method will be called when Electron has finished initialization and is
ready to create browser windows.

    app.on 'ready', ->

Create the browser window.

        mainWindow = new BrowserWindow { width: 1024, height: 768 }

refresh its content

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
            myUniverses[data.name].state = data.state
            updateUniverseLists()
