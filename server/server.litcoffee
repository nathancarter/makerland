
# Main Game Server

## HTTP

Start an HTTP server to serve game files.  Pass the responsibility off to
the file server, declared in the following separate module.

    fileserver = require './fileserver'

The following built-in node modules are relevant.

    http = require 'http'
    url = require 'url'

The entirety of the HTTP server is defined here.

    server = http.createServer ( request, response ) ->
        uri = ( url.parse request.url ).pathname
        if uri is '/'
            uri = 'client.html'
        if uri[...8] is '/upload/'
            try
                return handleUpload uri[8..], request, response
            catch e
                console.log 'Error uploading file', uri, 'Message:', e
        fileserver.serveFile uri, response
    .listen 9999

## Handling File Uploads

    { Player } = require './player'

First, make sure the folder for handling file uploads exists.  If it
doesn't, create it.  If you can't, abort with an error.

    fs = require 'fs'
    uploadFolder = require( './settings' ).getPath 'fileUploadFolder'
    try
        fs.mkdirSync uploadFolder
    catch e
        if e.code isnt 'EEXIST'
            console.log "Uploads folder does not exist, and could not create
                it.  Error when trying to create: #{e}"
            process.exit 1

Next, use busboy for multipart upload handling.  Any request to `/upload/X`
gets processed this way.  We keep a list of all data chunks sent, then use
`Buffer` to concat them all into one buffer at the end, which we send to the
client's chosen handler for all this.

    handleUpload = ( name, request, response ) ->
        busboy = require 'busboy'
        bb = new busboy { headers : request.headers }
        buffers = [ ]
        bb.on 'file', ( fieldname, file, others... ) ->
            file.on 'data', ( data ) -> buffers.push data
        bb.on 'finish', ->
            handler = Player.nameToPlayer( name )?.handlers?.__uploaded
            if handler instanceof Function
                buffer = Buffer.concat buffers
                handler buffer
            response.writeHead 200, Connection : 'close'
            response.end()
        request.pipe bb

## Web Sockets

Now extend that server so that it also listens for web socket connections
from the client side.  When a connection arrives, just create a Player
object for that client to control; its constructor handles everything.

    io = require( 'socket.io' ).listen server
    io.sockets.on 'connection', ( socket ) -> new Player socket

## Ctrl-C Handler

If the user who ran the game process presses Ctrl-C, we want to save all
players before exiting the game.  This handler does so.

    process.on 'SIGINT', ->
        player.save() for player in Player::allPlayers
        process.exit()
