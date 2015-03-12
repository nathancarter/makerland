
# Player Class

First, import required modules.

    accounts = ( require './database' ).accounts
    commands = require './commands'
    settings = require './settings'
    path = require 'path'

Each instance of the Player class represents a player in the game.

    module.exports.Player = class Player

## Class variables

The class maintains a list of all connected players, as a class variable.

        allPlayers : [ ]

You can look up a player by name with the following class method.

        @nameToPlayer : ( name ) ->
            for player in Player::allPlayers
                if player.name is name then return player
            null

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
                    if @handlers?[event.id]
                        @handlers[event.id] event
                    else
                        console.log 'No action handler installed for', event

If the event handler is a "contents changed" event, then we see if the
player object has within it a handler installed for watching changes.

                else if event.type is 'contents changed'
                    if @handlers?.__watcher
                        @handlers.__watcher event
                    else
                        console.log 'No handler installed to watch changes.'

Any other type we don't know how to handle, so we log it.

                else
                    console.log 'unknown ui event type:', event.type

If the event is a "command" event, then we see if the player has access to
the command in question, and if so, run it.

            socket.on 'command', ( event ) =>
                if event.name in @commands()
                    commands[event.name].run this
                else
                    console.log "Player #{@name} attempted to use the
                        command #{event.name} without permission."

If the event tells us where the player has moved, then notify the handler
for position changes.

            socket.on 'player position', ( data ) =>
                @positionChanged data.position, data.visionDistance

When this player disconnects, tell the console, and remove the player from
`allPlayers`.  Also, end the player's periodic status updates.

            socket.on 'disconnect', =>
                console.log "disconnected #{@name or 'a player'}"
                index = Player::allPlayers.indexOf this
                Player::allPlayers = Player::allPlayers[...index].concat \
                    Player::allPlayers[index+1..]
                console.log "there are now #{Player::allPlayers.length}"
                @stopStatusUpdates()
                @save()
                @positionChanged null, null

Now that the player object is set up, tell the client all the main game
settings and show the login screen.

            subset = { }
            subset[key] = settings[key] for key in settings.clientSettings
            socket.emit 'settings', subset
            @showLoginUI()

## User interface functions

The following function in the player sends a JSON structure to the client,
requesting that it show the UI defined by that structure.

        showUI : ( pieces... ) =>

If the function was called on a single array, rather than passed many
parameters, flatten it out.

            if pieces.length is 1 and pieces[0] instanceof Array
                pieces = pieces[0]

Clear out any action handlers installed before, then move any handlers in
the given data into this player.

            @handlers = { }
            count = 0
            installHandlers = ( piece ) =>
                if piece.type is 'action'
                    if not piece.action instanceof Function
                        console.log "Error: Cannot install handler for
                            action #{piece.value} because its action is not
                            a function."
                        return
                    piece.id = count
                    @handlers[count] = piece.action
                    delete piece.action
                    count++
                if piece.type is 'watcher'
                    @handlers.__watcher = piece.action
            for piece in pieces
                if piece instanceof Array
                    installHandlers entry for entry in piece
                else
                    installHandlers piece

Send the modified data on to the client.

            @socket.emit 'show ui', pieces

The following function prompts the user with a section of text, followed by
an OK button, and calls the given callback when the user clicks OK.  The
first parameter can be a string or an array of strings.

        showOK : ( text, callback = @showCommandUI ) =>
            if text not instanceof Array then text = [ text ]
            args = ( { type : 'text', value : t } for t in text )
            args.push {
                type : 'action'
                value : 'OK'
                action : callback
            }
            @showUI args

## The Login Process

This function tells the client to show a login UI.

        showLoginUI : =>
            controls = [
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
                default : yes
                action : ( event ) =>

Handle clicks of the "log in" button by verifying that the player's login
credentials are valid.

                    success = accounts.validLoginPair event.username,
                        event.password
                    if success
                        @loggedIn event.username
                    else
                        @showOK 'Invalid username and/or password.',
                            => @showLoginUI()
            ]
            if not settings.privateGame
                controls.push
                    type : 'action'
                    value : 'New account'
                    action : ( event ) =>

Handle clicks of the "new account" button by attempting to make the account,
but not overwriting any existing accounts.

                        if not event.username or not event.password
                            return @showOK 'You must supply both username
                                and password.', => @showLoginUI()
                        if accounts.exists event.username
                            return @showOK 'That username is already
                                taken.', => @showLoginUI()
                        try
                            accounts.create event.username, event.password
                            @loggedIn event.username
                        catch e
                            @showOK 'Error creating account: ' + e,
                                => @showLoginUI()
            @showUI controls

This method is called in the player when login succeeds.  It initializes the
player object with its name and tells the player they've succeeded in
logging in.

        loggedIn : ( @name ) =>
            @load()
            console.log "player logged in as #{name}"
            @startStatusUpdates()
            @showCommandUI()

## Player Status

This function creates a status object listing all data that the status
display should show about the player.

        getStatus : =>
            name : @name
            appearance : @saveData.avatar

This function checks the status periodically to see if it has changed.  If
so, it sends a status update message to the player.

        updateStatus : =>

First, update player age.

            @saveData or= { }
            @saveData.age or= 0
            @saveData.age += 2

Now track player status.

            currentStatus = JSON.stringify @getStatus()
            if @lastStatus? and currentStatus is @lastStatus then return
            @lastStatus = currentStatus
            @socket.emit 'status', currentStatus

We now provide two functions, one for beginning a periodic status update
query, and one for stopping that query.  The former is called at login, and
the latter at disconnection.

        startStatusUpdates : =>
            @updateStatus()
            @statusUpdateInterval = setInterval ( => @updateStatus() ), 2000
        stopStatusUpdates : =>
            clearInterval @statusUpdateInterval if @statusUpdateInterval?

## Loading and Saving Data

The player object contains a `saveData` field that includes all the data (as
key-value pairs) that get saved to disk as part of the player's permanent
record.  Any data outside that field is considered temporary, and can be
thrown away when the player logs out.

This function loads the player data from disk, based on the player's name.
We discard the password hash, so the player object doesn't carry that
around.

        load : =>
            @saveData = accounts.get @name
            delete @saveData.password

This function saves the player data to disk, after first putting the
password hash back in.

        save : =>
            if not @name then return
            toSave = JSON.parse JSON.stringify ( @saveData or { } )
            toSave.password = accounts.get @name, 'password'
            accounts.set @name, toSave

## Command Access

To what commands does the player have access?  This routine fetches that
information from the player's `saveData`.

        commands : =>

We treat the admin character special, always granting them access to all
commands at all times, even ones just added moments ago.

            if @name is 'admin'
                @saveData.commands = ( key for own key of commands )

The player may be new, and thus not have any commands; in that case we
populate the list of commands with all the basic commands.  We actually do
this for all players, so that in case anyone loses access to a basic
command, or a new basic command is invented, players will automatically have
access.

            @saveData.commands ?= [ ]
            for own key of commands
                if commands[key].category is 'basic'
                    if key not in @saveData.commands
                        @saveData.commands.push key
            @saveData.commands

This command shows the player the UI for all commands to which they have
access.

        showCommandUI : =>
            @showUI ( for command in @commands()
                iconPath = if commands[command].icon?
                    path.join settings.clientPath( 'commandIconFolder' ),
                        commands[command].icon
                else
                    undefined
                type : 'command'
                name : command[0].toUpperCase() + command[1..]
                category : commands[command].category
                shortInfo : commands[command].shortInfo
                help : commands[command].help
                icon : iconPath
            )

## Tracking Player Location

The following function updates player position data and asks the blocks
module to recompute visibility based on the given maximum vision distance.

        positionChanged : ( newPosition, visionDistance ) =>
            oldPosition = @position
            @position = newPosition
            require( './blocks' ).updateVisibility this, visionDistance,
                oldPosition
