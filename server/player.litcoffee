
# Player Class

Each instance represents a player in the game.

    module.exports.Player = class Player

The class maintains a list of all connected players, as a class variable.

        allPlayers : [ ]

The constructor accepts a socket object as parameter, the communication
channel to the client page used by this player.

        constructor : ( socket ) ->

Dump to the console a message about the connection, and add the player to
the class variable `allPlayers`.

            console.log 'connected a player'
            Player::allPlayers.push this
            console.log "there are now #{Player::allPlayers.length}"

Tell the client to show a login UI.

            socket.emit 'show ui', [
                type : 'text'
                value : 'Please log in to MakerLand!'
                align : 'center'
            ,
                type : 'string input'
                name : 'username'
            ,
                type : 'password input'
                name : 'password'
            ,
                type : 'action'
                value : 'Log in'
            ,
                type : 'action'
                value : 'New account'
            ]

Set up a handler for UI events from the client.

            socket.on 'ui event', ( event ) ->
                console.log 'client ui event:', event

When this player disconnects, tell the console, and remove the player from
`allPlayers`.

            socket.on 'disconnect', =>
                console.log 'disconnected a player'
                index = Player::allPlayers.indexOf this
                Player::allPlayers = Player::allPlayers[...index].concat \
                    Player::allPlayers[index+1..]
                console.log "there are now #{Player::allPlayers.length}"
