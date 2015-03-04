
# Player Class

Each instance represents a player in the game.

    module.exports.Player = class Player

## Class variables

The class maintains a list of all connected players, as a class variable.

        allPlayers : [ ]

## Constructor

The constructor accepts a socket object as parameter, the communication
channel to the client page used by this player.

        constructor : ( @socket ) ->

Dump to the console a message about the connection, and add the player to
the class variable `allPlayers`.

            console.log 'connected a player'
            Player::allPlayers.push this
            console.log "there are now #{Player::allPlayers.length}"

Set up a handler for UI events from the client.

            socket.on 'ui event', ( event ) =>

If the event is an "action taken" event, then we see if the player object
has within it a handler installed for that event.

                if event.type is 'action taken'
                    if @handlers?[event.action]
                        @handlers[event.action] event
                    else
                        console.log 'No action handler installed for', event

Any other type we don't know how to handle, so we log it.

                else
                    console.log 'unknown ui event type:', event.type

When this player disconnects, tell the console, and remove the player from
`allPlayers`.

            socket.on 'disconnect', =>
                console.log 'disconnected a player'
                index = Player::allPlayers.indexOf this
                Player::allPlayers = Player::allPlayers[...index].concat \
                    Player::allPlayers[index+1..]
                console.log "there are now #{Player::allPlayers.length}"

Now that the player object is set up, show the player the login screen.

            @showLoginUI()

## User interface functions

The following function in the player sends a JSON structure to the client,
requesting that it show the UI defined by that structure.

        showUI : ( pieces... ) =>

Clear out any action handlers installed before, then move any handlers in
the given data into this player.

            @handlers = { }
            for piece in pieces
                if piece.type is 'action'
                    @handlers[piece.value] = piece.action
                    delete piece.action

Send the modified data on to the client.

            @socket.emit 'show ui', pieces

The following function prompts the user with a section of text, followed by
an OK button, and calls the given callback when the user clicks OK.

        showOK : ( text, callback ) =>
            @showUI
                type : 'text'
                value : text
            ,
                type : 'action'
                value : 'OK'
                action : callback

This function tells the client to show a login UI.

        showLoginUI : =>
            @showUI
                type : 'text'
                value : '<h3>Please log in to MakerLand!</h3>'
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
                action : =>
                    @showOK 'Log in not yet implemented.', => @showLoginUI()
            ,
                type : 'action'
                value : 'New account'
                action : =>
                    @showOK 'New account not yet implemented.',
                        => @showLoginUI()
