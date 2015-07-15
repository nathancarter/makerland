
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
            name = name.toLowerCase()
            for player in Player::allPlayers
                if player.name is name then return player
            null

## Constructor

The constructor accepts a socket object as parameter, the communication
channel to the client page used by this player.

        constructor : ( @socket ) ->

Dump to the console a message about the connection, and add the player to
the class variable `allPlayers`.  Initialize their save data to an empty
object, since we have not loaded any particular player data yet.

            Player::allPlayers.push this
            console.log "Connected a player; there are now
                #{Player::allPlayers.length} players."
            @saveData = { }
            @statusConditions = [ ]

Set up a handler for UI events from the client.

            socket.on 'ui event', ( event ) =>

If the event is an "action taken" event or a "map click" event, then we see
if the player object has within it a handler installed for that event.

                if event.type in [ 'action taken', 'map click' ]
                    if @uihandlers?[event.id]
                        @uihandlers[event.id] event
                    else
                        console.log 'ERROR: No action handler installed
                            for', event

If the event handler is a "contents changed" event, then we see if the
player object has within it a handler installed for watching changes.

                else if event.type is 'contents changed'
                    if @uihandlers?.__watcher
                        @uihandlers.__watcher event
                    else
                        console.log 'ERROR: No handler installed to watch
                            changes.'

Any other type we don't know how to handle, so we log it.

                else
                    console.log 'ERROR: Unknown ui event type:', event.type

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

When this player disconnects, drop all their possessions, tell the console,
and remove the player from `allPlayers`.  Also, end the player's periodic
status updates.

            socket.on 'disconnect', =>
                for item in @inventory ? [ ]
                    item.move @getPosition()
                index = Player::allPlayers.indexOf this
                Player::allPlayers.splice index, 1
                console.log "Disconnected #{@name or 'a player'};
                    there are now #{Player::allPlayers.length} players."
                @stopStatusUpdates()
                @save()
                oldPosition = @getPosition()
                @positionChanged null, null
                require( './animations' ).showAnimation oldPosition,
                    'logout', { player : @name, position : oldPosition }
                require( './sounds' ).playSound 'teleport', oldPosition
                if @intervalSetIndex?
                    require( './behaviors' ).clearIntervalSet \
                        @intervalSetIndex

The client may also request data about the cell types, landscape items, and
movable items in the map.  When they do, we must provide it, so they have
enough information to draw the map.

            socket.on 'get cell type data', ( index ) =>
                result = require( './celltypes' ).getWithDefaults index
                if result
                    result.index = index
                    socket.emit 'cell type data', result
            socket.on 'get landscape item data', ( index ) =>
                result = require( './landscapeitems' ).getWithDefaults index
                if result
                    result.index = index
                    socket.emit 'landscape item data', result
            socket.on 'get movable item data', ( index ) =>
                result = require( './movableitems' ).getWithDefaults index
                if result
                    result.index = index
                    socket.emit 'movable item data', result
            socket.on 'get creature data', ( index ) =>
                result = require( './creatures' ).getWithDefaults index
                if result
                    result.index = index
                    socket.emit 'creature data', result

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

            @uihandlers = if @uihandlers?.__uploaded
                __uploaded : @uihandlers.__uploaded
            else
                { }
            count = 0
            installHandlers = ( piece ) =>
                if piece.type in [ 'action', 'upload button', 'map click' ]
                    if not piece.action instanceof Function
                        console.log "ERROR: Cannot install handler for
                            action #{piece.value} because its action is not
                            a function."
                        return
                    piece.id = count
                    @uihandlers[count] = piece.action
                    delete piece.action
                    count++
                if piece.type is 'watcher'
                    @uihandlers.__watcher = piece.action
                if piece.type is 'upload file'
                    @uihandlers.__uploaded = piece.action
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
            args.push
                type : 'action'
                value : 'OK'
                cancel : yes
                action : callback
            @showUI args

The following function presents a file upload UI, returning control to the
callback when completed.  Provide a title string for the UI page, any other
instructions as a subtitle string, plus a callback to be called when the
user either cancels the upload UI or finishes an upload and then clicks OK
on the next screen (which just says the file upload has been started).  The
final parameter is the handler for when the upload completes, and should do
something with the file.  (It will receive the file's contents as a
parameter; the file will have been removed from disk, and should be re-saved
elsewhere if needed.)

        getFileUpload : ( title, subtitle = '',
        uiCallback = @showCommandUI, handler ) =>
            if subtitle isnt '' then subtitle = "<p>#{subtitle}</p>"
            @showUI
                type : 'text'
                value : "<h3>Upload File: #{title}</h3>#{subtitle}"
            ,
                type : 'upload file'
                action : handler
            ,
                type : 'upload button'
                action : => @showOK 'Upload started.', uiCallback
            ,
                type : 'action'
                value : 'Cancel'
                cancel : yes
                action : uiCallback

The following function tells the player that he/she can click anywhere on
the map to accomplish a specific action.  This routine calls the given click
callback whenever the player does so, with map coordinates (in game world
coordinates, not screen coordinates) each time the player clicks.  The mode
ends when the player chooses the Done button (or hits Esc).  The CSS cursor
style given as the fourth parameter applies over the game view during this
mode.

The `instructions` parameter is the text to be shown on the screen.  It will
have above it a heading that says "Click the map" and a button below it that
says "Exit," but that's all.  Thus the instructions should say what will
happen when the player clicks.  The click handler does not need to display
another UI to the player; it can leave this UI visible, so that the player
can click repeatedly.  Or it can display another UI if that's preferred.
The instructions should give the player the correct expectation of this
behavior.

The click handler will receive the map coordinates as two parameters, x and
y.  These will not usually be integers, since players can click strictly
inside map cells, not just on their corners.

        mapClickMode : ( instructions, clickHandler,
        uiCallback = @showCommandUI, cursor = 'crosshair' ) =>
            @showUI
                type : 'text'
                value : '<h3>Click the map</h3>'
            ,
                type : 'map click'
                value : instructions
                cursor : cursor
                action : ( data ) ->
                    clickHandler data.location.x, data.location.y
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : uiCallback

## The Login Process

This function tells the client to show a login UI.

        showLoginUI : =>
            controls = [
                type : 'text'
                align : 'center'
                value : settings.gameTitle
                splash : settings.gameTitleImage
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
                        event.username = event.username.toLowerCase()
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
logging in.  Note the first two lines, which check to see if the player is
already logged in elsewhere in the game, and if so, disconnects that other
client before allowing this one to take over.

This function behaves differently if the player is just logging back in,
versus logging back in for the first time since they died.

        loggedIn : ( name ) =>
            if otherCopy = Player.nameToPlayer name
                otherCopy.socket.disconnect()
            @name = name
            @load()
            if @saveData.timeOfDeath?
                elapsed = ( new Date ) - ( new Date @saveData.timeOfDeath )
                if elapsed > settings.timePlayersStayDeadInSeconds * 1000
                    @awakenFromDeath()
                    @saveData.position =
                        settings.locationPlayersAwakeAfterDeath ? \
                        [ 0, 0, 0 ]
                else
                    delete @name
                    @saveData = { }
                    @showOK "You cannot log back in again yet as
                        #{name[0].toUpperCase() + name[1..]}.  That
                        character is still deep in death.",
                        => @socket.disconnect()
                    return
            @justLoggedIn = yes
            console.log "\tPlayer logged in as #{name}."
            destination =
                if require( './blocks' ).validPosition @getPosition(), this
                    @getPosition()
                else
                    [ 0, 0, 0 ]
            @teleport destination
            @startStatusUpdates()
            @showCommandUI()
            require( './animations' ).showAnimation destination, 'login',
                player : name
            require( './sounds' ).playSound 'teleport', destination

## Player Status

This function creates a status object listing all data that the status
display should show about the player.

The initial loop in this routine is to ensure that we only send on
information about commands to which the player actually has access, even if
he/she formerly had access to (and created shortcuts for) a larger set of
commands.

        getStatus : =>
            shortcuts = { }
            hudshorts = { }
            @saveData.shortcuts ?= { }
            @saveData.hudshorts ?= { }
            for command in @commands().concat [ 'hide/show command panel' ]
                shortcuts[command] = @saveData.shortcuts[command]
                hudshorts[command] = @saveData.hudshorts[command]
            if ( plane = @getPosition()?[0] )?
                btable = require './blocks'
                defaultCellType = btable.get btable.planeKey( plane ),
                    'default cell type'
            else
                defaultCellType = -1
            result =
                name : @name
                appearance : @saveData.avatar
                shortcuts : shortcuts
                HUD : hudshorts
                isMaker : @isMaker()
                defaultCellType : defaultCellType
                conditions : ( c.text for c in @statusConditions )
                movementRate : @getStat 'movement rate'
            @addHealthToStatus result
            result

This function checks the status periodically to see if it has changed.  If
so, it sends a status update message to the player.

        updateStatus : =>

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
            @statusUpdateInterval = setInterval =>
                @saveData.age ?= 0
                @saveData.age += 2
                @heartBeat()
                @updateStatus()
                now = new Date
                @statusConditions = ( c for c in @statusConditions \
                    when c.expires > now )
            , 2000
        stopStatusUpdates : =>
            clearInterval @statusUpdateInterval if @statusUpdateInterval?

Players can also have "status conditions."  These are very short bits of
text that are added to the player status, and come with a predetermined time
until expiration.  These can be anything from a simple alert message that's
too brief to require the command pane, up to a special status earned as part
of a quest that will last 10 minutes, and is needed for the next step in the
quest.  Examples: "You feel poisoned," a brief warning lasting 10 seconds,
for the player's information only.  "The priest has blessed you," a status
needed by a quest, which lasts 10 minutes.  The duration parameter is
measured in seconds.  All status conditions disappear on logout.

        addStatusCondition : ( text, duration ) =>
            @statusConditions.push
                text : text
                expires : new Date ( new Date ).getTime() + duration*1000
            @updateStatus()

## Loading and Saving Data

The player object contains a `saveData` field that includes all the data (as
key-value pairs) that get saved to disk as part of the player's permanent
record.  Any data outside that field is considered temporary, and can be
thrown away when the player logs out.

This function loads the player data from disk, based on the player's name.
We discard the password hash, so the player object doesn't carry that
around.  The load function creates a shallow copy, because we are about to
delete the password from the copy, and we don't want to mess up the cache in
the accounts table by messing with its original copy.

        load : =>
            @saveData = { }
            for own key, value of accounts.getWithDefaults @name
                @saveData[key] = value
            delete @saveData.password
            @initLiving()

This function saves the player data to disk, after first putting the
password hash back in.

        save : =>
            if not @name then return
            toSave = JSON.parse JSON.stringify @saveData
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

            @saveData.commands ?= [ 'quit' ]
            @saveData.commands

Grant a player new commands by calling this routine.  It first verifies that
the commands to be granted are ones that exist in the game.

        grantCommand : ( command ) =>
            if commands.hasOwnProperty( command ) and \
               command not in @saveData.commands
                @saveData.commands.push command
                return yes
            no

We determine whether a player is a maker or not based on whether they have
access to the "database" command.

        isMaker : => 'database' in @commands()

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
                category : "#{commands[command].category} Commands"
                shortInfo : commands[command].shortInfo
                help : commands[command].help
                icon : iconPath
            )

## Player Inventory

If someone else inspects this player, we just show them our inventory.

        gotInspectedBy : ( otherPlayer ) =>
            otherPlayer.showUI @inventoryInspected().concat [
                type : 'action'
                value : 'Done'
                cancel : yes
                action : -> otherPlayer.showCommandUI()
            ]

## Player Location

While the player's position will be stored in their `saveData`, we provide
the following convenience functions for getting and setting it without
needing to address the `saveData` member directly.

        getPosition : => @saveData.position?.slice()
        setPosition : ( newposition ) => @saveData.position = newposition

The following function updates player position data and asks the blocks
module to recompute visibility based on the given maximum vision distance.
If the player's new position isn't valid, then we use the `teleport`
function to tell the client to put the player back to their previous (valid)
position.

        positionChanged : ( newPosition, visionDistance ) =>
            oldPosition = if @justLoggedIn then null else @getPosition()
            delete @justLoggedIn
            if require( './blocks' ).validPosition newPosition, this
                @setPosition newPosition
                if newPosition?[0] isnt oldPosition?[0] then @updateStatus()
            else
                @teleport @getPosition()
            require( './blocks' ).updateVisibility this, visionDistance,
                oldPosition

The following command teleports a player from one location in the game to
another.  It does so by telling the client about the new position, and the
client, in turn, tells the server not only the new position, but also the
vision distance, which results in a call to `positionChanged`.

        teleport : ( destination ) =>
            @positionChanged destination, 10
            @socket.emit 'player position', destination

Get all players within a certain radius of the given position.

    module.exports.playersNearPosition = ( position, radius ) ->
        extremes = [
            position
            [ position[0], position[1]-1, position[2] ]
            [ position[0], position[1]+1, position[2] ]
            [ position[0], position[1], position[2]-1 ]
            [ position[0], position[1], position[2]+1 ]
        ]
        distance = ( x1, y1, x2, y2 ) ->
            Math.sqrt ( x1 - x2 ) * ( x1 - x2 ) \
                    + ( y1 - y2 ) * ( y1 - y2 )
        results = [ ]
        for player in Player::allPlayers
            if not ( pp = player.getPosition() )? then continue
            if pp[0] isnt position[0] then continue
            if distance( pp[1], pp[2], position[1], position[2] ) \
                < radius then results.push player
        results

Mix handlers and health into `Player`s.

    require( './handlers' ).mixIntoClass Player
    require( './living' ).mixIntoClass Player
