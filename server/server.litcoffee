
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
        fileserver.serveFile uri, response
    .listen 9999

## Web Sockets

Now extend that server so that it also listens for web socket connections
from the client side.  When a connection arrives, print it to the console.

    io = require( 'socket.io' ).listen server
    io.sockets.on 'connection', ( socket ) ->
        console.log 'connected a client'

Set up responses to two events.  First, if the client sends a command, for
now just dump it to the console for testing.

        socket.on 'command', ( command ) ->
            console.log 'client sent this:', command

Second, if the client disconnects, print that as well.

        socket.on 'disconnect', ->
            console.log 'disconnected a client'
