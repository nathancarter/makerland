
# Player Class

This module needs access to the accounts module.

    accounts = ( require './database' ).accounts
    commands = require './commands'

Each instance of the Player class represents a player in the game.

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
`allPlayers`.  Also, end the player's periodic status updates.

            socket.on 'disconnect', =>
                console.log "disconnected #{@name or 'a player'}"
                index = Player::allPlayers.indexOf this
                Player::allPlayers = Player::allPlayers[...index].concat \
                    Player::allPlayers[index+1..]
                console.log "there are now #{Player::allPlayers.length}"
                @stopStatusUpdates()
                @save()

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

## The Login Process

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
            ,
                type : 'action'
                value : 'New account'
                action : ( event ) =>

Handle clicks of the "new account" button by attempting to make the account,
but not overwriting any existing accounts.

                    if not event.username or not event.password
                        return @showOK 'You must supply both username and
                            password.', => @showLoginUI()
                    if accounts.exists event.username
                        return @showOK 'That username is already taken.',
                            => @showLoginUI()
                    try
                        accounts.create event.username, event.password
                        @loggedIn event.username
                    catch e
                        @showOK 'Error creating account: ' + e,
                            => @showLoginUI()

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

        getStatus : => name : @name

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

If the data is empty (because the player object was just created) this
populates it with the set of basic commands to which all players should have
access.

            if not @saveData.commands?
                @saveData.commands = [ 'quit' ]
            @saveData.commands

This command shows the player the UI for all commands to which they have
access.

        showCommandUI : =>
            @showUI.apply this, ( for command in @commands()
                type : 'command'
                name : command[0].toUpperCase() + command[1..]
                category : commands[command].category
                shortInfo : commands[command].shortInfo
            )
