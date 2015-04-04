
# Main Game Server

## HTTP

Start an HTTP server to serve game files.  Pass the responsibility off to
the file server, declared in the following separate module.  We also need to
be able to look up some global settings.

    fileserver = require './fileserver'
    settings = require './settings'

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
    .listen settings.port or 9999

## Handling File Uploads

    { Player } = require './player'

First, make sure the folder for handling file uploads exists.  If it
doesn't, create it.  If you can't, abort with an error.

    fs = require 'fs'
    uploadFolder = settings.getPath 'fileUploadFolder'
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
        console.log "\nReceived Ctrl+C signal.
            Saving all players before quitting..."
        for player in Player::allPlayers
            console.log "\tSaving #{player.name}..."
            player.save()
        console.log 'Done.'
        process.exit()

## Detecting IP Address

We want to tell the user their internal IP address, which will be known to
their own computer's network interfaces.  So we query those.

    console.log 'Game ready to receive connections.'
    message = 'Internal users connect here'
    for own name, list of require( 'os' ).networkInterfaces()
        for iface in list
            if iface.family is 'IPv4' and iface.address isnt '127.0.0.1'
                console.log "\t#{message}:\t
                    http://#{iface.address}:#{settings.port or 9999}"
                message = 'Alternate internal address'

We want to tell the user running the server process what their internal and
external IP addresses are, so that they can advertise these facts to anyone
whom they want to join them in the game.

    require( 'request' ) 'http://www.myexternalip.com',
        ( error, response, body ) ->
            if error
                console.log 'Error attempting to find external IP address:',
                    error.message, '\n'
            else if response.statusCode isnt 200
                console.log 'Attempting to find external IP address gave
                    bad HTTP status code:', response.statusCode, '\n'
            else if match = /data-ip="([^"]+)"/.exec body
                console.log "\tExternal users connect here:\t
                    http://#{match[1]}:#{settings.port or 9999}\n"
            else
                console.log 'Could not find external IP address.\n'
