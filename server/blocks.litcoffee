
# Map Block Table

This module implements the database table for storing map blocks.

First, let's import some things we'll need below.

    settings = require './settings'
    { Player } = require './player'
    { Table } = require './table'

## Table Subclass

This module implements a database table by subclassing the main Table class
and adding map-block-specific functionality.

    class BlocksTable extends Table

## Constructor

The constructor just names the table, then ensures that the main plane of
the game is editable only by the admin character.

        constructor : () ->
            super 'blocks'
            if not @getAuthors @planeKey 0
                @setAuthors @planeKey( 0 ), [ 'admin' ]

Implement routines for getting and setting blocks of cells.  Each requires
plane, x, and y to be numbers, and it rounds x and y down to the nearest
(lower) multiples of N.  It ensures plane is an integer.  The set routine
ensures that the cells array is of the correct size and full of only
integers.

        getCells : ( plane, x, y ) =>
            if typeof plane isnt 'number' or typeof x isnt 'number' or \
               typeof y isnt 'number' then return null
            plane = plane | 0
            N = settings.mapBlockSizeInCells
            x = ( N * Math.floor x/N ) | 0
            y = ( N * Math.floor y/N ) | 0
            key = "#{plane},#{x},#{y}"
            if not @exists key
                @set key, { }
                @set key, 'cells',
                    ( ( -1 for i in [1..N] ) for i in [1..N] )
            @get key, 'cells'
        setCells : ( plane, x, y, array ) =>
            if typeof plane isnt 'number' or typeof x isnt 'number' or \
               typeof y isnt 'number' then return
            if array not instanceof Array then return
            for row in array
                if row not instanceof Array then return
                for item, index in row
                    if typeof item isnt 'number' then return
                    row[index] = item | 0
            plane = plane | 0
            N = settings.mapBlockSizeInCells
            x = ( N * Math.floor x/N ) | 0
            y = ( N * Math.floor y/N ) | 0
            key = "#{plane},#{x},#{y}"
            if not @exists key then @set key, { }
            @set key, 'cells', array
            notifyAboutBlockUpdate key

You can also get or set just one cell at a time, with the following
functions.

        getCell : ( plane, x, y ) =>
            block = @getCells plane, x, y
            if not block then return null
            N = settings.mapBlockSizeInCells
            dx = ( x - ( N * Math.floor x/N ) ) | 0
            dy = ( y - ( N * Math.floor y/N ) ) | 0
            block[dx][dy]
        setCell : ( plane, x, y, i ) =>
            block = @getCells plane, x, y
            if not block then return null
            N = settings.mapBlockSizeInCells
            dx = ( x - ( N * Math.floor x/N ) ) | 0
            dy = ( y - ( N * Math.floor y/N ) ) | 0
            block[dx][dy] = parseInt i
            @setCells plane, x, y, block

## Planes

This table actually serves a dual purpose.  Not only does it store blocks,
but it also stores planes.  That is, it has entries of both types.  Here we
create functions relevant to the storing of planes.

First, the function that creates the table key for plane with index i.

        planeKey : ( i ) -> "plane #{i}"
        isPlaneKey : ( key ) -> /^plane \d+$/.test key
        indexOfPlaneKey : ( key ) -> parseInt key.split( ' ' ).pop()

Now, when asked for entries, we only want to return planes, not the (tons!)
of individual blocks.  Also, they should be sorted numerically by indices.

        entries : =>
            result = ( entry for entry in super() when @isPlaneKey entry )
            result.sort ( a, b ) =>
                @indexOfPlaneKey( a ) - @indexOfPlaneKey( b )

An entry is shown as its index and name together.

        show : ( entry ) =>
            "#{@indexOfPlaneKey entry}. #{@get entry, 'name'}"

Any maker can add new entries to the table, but that means adding planes,
not new blocks.  The UI for doing so looks like the following.

        canAdd : -> yes
        add : ( player, callback = -> player.showCommandUI() ) =>
            i = 0
            while @exists @planeKey i
                i++
            @set @planeKey( i ), name : 'new plane'
            @setAuthors @planeKey( i ), [ player.name ]
            player.showOK "A new plane was created with index #{i}.
                You have been set as its only author.
                Feel free to edit it to suit your needs.",
                => callback @planeKey i

Who can edit individual planes is determined by the plane's authors list,
which is the default implementation of `canEdit` in the `Table` class.

The UI for editing a plane looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            if not @isPlaneKey entry
                return player.showOK 'Error.  Somehow you have attempted to
                    edit something other than a plane.  This is not
                    permitted.', callback
            data = @get entry
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h4>Editing #{entry}:</h4>"
            ,
                [
                    type : 'text'
                    value : 'Name:'
                ,
                    type : 'text'
                    value : data.name
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing name of #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new plane name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new plane name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of #{entry} changed to
                                    #{newname}.", again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ,
                [
                    type : 'text'
                    value : 'Authors:'
                ,
                    type : 'text'
                    value : @getAuthors entry
                ,
                    type : 'action'
                    value : 'Change'
                    action : => require( './ui' ).editAuthorsList player,
                        this, entry, again
                ]
            ,
                type : 'action'
                value : 'Teleport to this plane'
                action : =>
                    plane = @indexOfPlaneKey entry
                    player.teleport [ plane, 0, 0 ]
                    callback()
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback

A maker can remove an entry if and only if it is a plane that that maker can
edit.

        canRemove : ( player, entry ) =>
            @isPlaneKey( entry ) and @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove #{entry} <i>permanently</i>.  This action
                 <i>cannot</i> be undone!", action, callback

Export a singleton of the class as the module.

    module.exports = new BlocksTable

## Non-table Functions

Here is a function that computes, for a given point on the map, the name of
the block containing that point.  A block name is the point at the top-left
corner of the block.

    blockName = module.exports.blockName = ( position ) ->
        size = settings.mapBlockSizeInCells
        x = size * Math.floor position[1] / size
        y = size * Math.floor position[2] / size
        [ position[0], x, y ]

The following two global data structures map players to the blocks they can
see, and blocks to the players who can see them.  Each map uses player names
and block names as strings (all lower case).

    blocksVisibleToPlayer = { }
    playersWhoCanSeeBlock = { }

Below we have a function that's called by the player object for any player
that moves.  We use it to update the above two mappings, so that this module
can send information to clients about what's moving on their screen.  But
first we need the function we'll use to send the notification to clients.

    notifyAboutMovement = ( notifyThisPlayer, aboutThisPlayer, position ) ->
        notifyThisPlayer?.socket.emit 'movement nearby',
            type : 'player'
            name : aboutThisPlayer.name
            appearance : aboutThisPlayer.saveData?.avatar
            position : position

Now that we have that function, here's the bigger function that uses it.

    module.exports.updateVisibility =
    ( player, visionDistance, oldPosition ) ->

First, compute what blocks are visible to the given player now.

        visibleBlocks = [ ]
        if p = player.getPosition()
            plane = p[0]
            x = p[1] - visionDistance
            while x < p[1] + visionDistance
                y = p[2] - visionDistance
                while y < p[2] + visionDistance
                    visibleBlocks.push "#{blockName [ plane, x, y ]}"
                    y += settings.mapBlockSizeInCells
                x += settings.mapBlockSizeInCells

Store that in the mapping `blocksVisibleToPlayer`, but not before we keep a
copy of its old value for use below.

        formerlyVisibleBlocks = blocksVisibleToPlayer[player.name] ? [ ]
        blocksVisibleToPlayer[player.name] = visibleBlocks

Next, for any block that was recently visible but became invisible, remove
the player from its entry in `playersWhoCanSeeBlock`.

        blockSetChanged = no
        for block in formerlyVisibleBlocks
            if block not in visibleBlocks
                blockSetChanged = yes
                if array = playersWhoCanSeeBlock[block]
                    i = array.indexOf player.name
                    if i > -1 then array.splice i, 1

Next, for any block that was recently invisible but became visible, add the
player to its entry in `playersWhoCanSeeBlock`.  Also, notify the player of
the locations of anyone in that block, since they can now see it.

        for block in visibleBlocks
            if block not in formerlyVisibleBlocks
                blockSetChanged = yes
                playersWhoCanSeeBlock[block] ?= [ ]
                for otherPlayer in playersWhoCanSeeBlock[block]
                    otherPlayer = Player.nameToPlayer otherPlayer
                    theirBlock = "#{blockName otherPlayer.getPosition()}"
                    if theirBlock is block
                        notifyAboutMovement player, otherPlayer,
                            otherPlayer.getPosition()
                playersWhoCanSeeBlock[block].push player.name

Now notify all players who could see the player's current or former block
that the player moved.

        toNotify = if oldPosition
            playersWhoCanSeeBlock[blockName oldPosition]
        else
            [ ]
        maybeMore = if p
            playersWhoCanSeeBlock[blockName p]
        else
            [ ]
        for name in maybeMore
            if name not in toNotify then toNotify.push name
        for name in toNotify
            canStillSee = name in maybeMore
            if name isnt player.name
                notifyAboutMovement Player.nameToPlayer( name ),
                    player, if canStillSee then p else null

Also, any players whose set of visible blocks changed, notify those players
about their new set of visible blocks.

        if blockSetChanged then notifyAboutVisibility player, visibleBlocks

The following function notifies players about their set of visible blocks.

    notifyAboutVisibility = ( notifyThisPlayer, blockSet ) ->
        if not notifyThisPlayer then return
        data = { }
        for block in blockSet
            [ plane, x, y ] = ( parseInt i for i in block.split ',' )
            data[block] = module.exports.getCells plane, x, y
        notifyThisPlayer.socket.emit 'visible blocks', data

And when a block is edited by a maker, we want to call the above function on
every player who can see the block.

    notifyAboutBlockUpdate = ( blockName ) ->
        for playerName in playersWhoCanSeeBlock[blockName]
            player = Player.nameToPlayer playerName
            if player
                notifyAboutVisibility player,
                    blocksVisibleToPlayer[playerName]
