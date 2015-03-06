
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
from the client side.  When a connection arrives, just create a Player
object for that client to control; its constructor handles everything.

    io = require( 'socket.io' ).listen server
    Player = require( './player' ).Player
    io.sockets.on 'connection', ( socket ) -> new Player socket

## Ctrl-C Handler

If the user who ran the game process presses Ctrl-C, we want to save all
players before exiting the game.  This handler does so.

    process.on 'SIGINT', ->
        player.save() for player in Player::allPlayers
        process.exit()
