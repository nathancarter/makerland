
# Player Class

Each instance represents a player in the game.

    class Player

The constructor accepts a socket object as parameter, the communication
channel to the client page used by this player.

        constructor : ( socket ) ->
            console.log 'connected a player'
            socket.on 'ui event', ( event ) ->
                console.log 'client ui event:', event
            socket.on 'disconnect', ->
                console.log 'disconnected a player'

    module.exports.Player = Player
