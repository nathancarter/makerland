
# Map Block Table

This module implements the database table for storing map blocks.

First, let's import some things we'll need below.

    settings = require './settings'
    { Player } = require './player'
    { Table } = require './table'

The following two global data structures map players to the blocks they can
see, and blocks to the players who can see them.  Each map uses player names
and block names as strings (all lower case).  These are maintained by functions in the section "Non-table Functions", below.

    blocksVisibleToPlayer = { }
    playersWhoCanSeeBlock = { }

## Table Subclass

This module implements a database table by subclassing the main Table class
and adding map-block-specific functionality.

    class BlocksTable extends Table

## Constructor

The constructor just names the table, then ensures that the main plane of
the game is editable only by the admin character.

        constructor : () ->
            super 'blocks', 'Planes'
            if not @getAuthors @planeKey 0
                @setAuthors @planeKey( 0 ), [ 'admin' ]
            @setDefault 'default cell type', -1

## Specialized Getters and Setters

Implement routines for getting and setting blocks of cells.  Each requires
plane, x, and y to be numbers, and it rounds x and y down to the nearest
(lower) multiples of N.  It ensures plane is an integer.  The set routine
ensures that the cells array is of the correct size and full of only
integers.

        positionToBlockName : ( plane, x, y ) ->
            if typeof plane isnt 'number' or typeof x isnt 'number' or \
               typeof y isnt 'number' then return null
            plane = plane | 0
            N = settings.mapBlockSizeInCells
            x = ( N * Math.floor x/N ) | 0
            y = ( N * Math.floor y/N ) | 0
            "#{plane},#{x},#{y}"
        getBlock : ( plane, x, y ) =>
            if not key = @positionToBlockName plane, x, y then return null
            if not @exists key
                N = settings.mapBlockSizeInCells
                @set key,
                    cells : ( ( -1 for i in [1..N] ) for i in [1..N] )
                    'landscape items' : [ ]
            @get key
        setBlock : ( plane, x, y, block ) =>
            if not key = @positionToBlockName plane, x, y then return
            if not @exists key then @set key, { }
            @set key, block
            module.exports.notifyAboutBlockUpdate key

When getting block data, we provide our own default values rather than using
the `@setDefault` method, because many of the default values are arrays, and
we want a different array for every block, rather than having one instance
shared, which could have data from one block unintentionally polluting
another.

        getBlockData : ( plane, x, y, key ) =>
            if not block = @getBlock plane, x, y then return null
            if not block.hasOwnProperty key
                dflt = undefined
                if key is 'cells'
                    N = settings.mapBlockSizeInCells
                    dflt = ( ( -1 for i in [1..N] ) for i in [1..N] )
                if key is 'landscape items'
                    dflt = [ ]
                if typeof dflt isnt 'undefined'
                    block[key] = dflt
                    @setBlock plane, x, y, block
            block[key]
        setBlockData : ( plane, x, y, key, value ) =>
            if not block = @getBlock plane, x, y then return
            if key is 'cells'
                if value not instanceof Array then return
                for row in value
                    if row not instanceof Array then return
                    for item, index in row
                        if typeof item isnt 'number' then return
                        row[index] = item | 0
            block[key] = value
            @setBlock plane, x, y, block

We also provide convenience functions for getting/setting the cell grid of a
block, as well as getting/setting just one cell at a time.

        getCells : ( plane, x, y ) => @getBlockData plane, x, y, 'cells'
        setCells : ( plane, x, y, array ) =>
            @setBlockData plane, x, y, 'cells', array
        positionToBlockIndices : ( plane, x, y ) ->
            N = settings.mapBlockSizeInCells
            dx = ( x - ( N * Math.floor x/N ) ) | 0
            dy = ( y - ( N * Math.floor y/N ) ) | 0
            if dx >= N then dx = N - 1 # prevent float rounding inaccuracies
            if dy >= N then dy = N - 1 # prevent float rounding inaccuracies
            [ dx, dy ]
        getCell : ( plane, x, y ) =>
            block = @getCells plane, x, y
            if not block then return null
            [ dx, dy ] = @positionToBlockIndices plane, x, y
            block[dx][dy]
        setCell : ( plane, x, y, i ) =>
            block = @getCells plane, x, y
            if not block then return null
            [ dx, dy ] = @positionToBlockIndices plane, x, y
            block[dx][dy] = parseInt i
            @setCells plane, x, y, block

When editing the map, makers will want to add new landscape items.  These
are uniquely identified by their positions, which we must therefore ensure
are unique.  We do not allow adding a landscape item to within one decimal
place (in cells, in x or y) of another landscape item, to ensure uniqueness.

        pointsAreClose : ( x1, y1, x2, y2 ) ->
            Math.abs( x1 - x2 ) < 0.1 and Math.abs( y1 - y2 ) < 0.1
        addLandscapeItem : ( plane, x, y, itemIndex ) =>
            items = @getBlockData plane, x, y, 'landscape items'
            N = settings.mapBlockSizeInCells
            blockx = x - N * Math.floor x/N
            blocky = y - N * Math.floor y/N
            for item in items or [ ]
                if @pointsAreClose item.position[0], item.position[1], \
                    blockx, blocky then return no
            items.push { type : itemIndex, position : [ blockx, blocky ] }
            @setBlockData plane, x, y, 'landscape items', items
            yes
        getLandscapeItem : ( plane, x, y ) =>
            items = @getBlockData plane, x, y, 'landscape items'
            N = settings.mapBlockSizeInCells
            blockx = x - N * Math.floor x/N
            blocky = y - N * Math.floor y/N
            for item in items or [ ]
                if @pointsAreClose item.position[0], item.position[1], \
                    blockx, blocky then return item
            null

Makers can also remove landscape items based on their coordinates, again
uniquely identifying a landscape item by its position, up to one decimal
place of accuracy.

        removeLandscapeItem : ( plane, x, y ) =>
            items = @getBlockData plane, x, y, 'landscape items'
            N = settings.mapBlockSizeInCells
            blockx = x - N * Math.floor x/N
            blocky = y - N * Math.floor y/N
            @setBlockData plane, x, y, 'landscape items',
                ( item for item in items when not @pointsAreClose \
                  item.position[0], item.position[1], blockx, blocky )

To update an landscape item, which means saving its latest data into the
block that already contains the item, pass the item to the following
function.  This function finds the block containing the item, then finds the
item data within that block, then updates it to match the content of the
object passed as parameter.

        setLandscapeItem : ( updatedItem ) =>
            { plane, x, y, type, behaviors } = updatedItem
            items = @getBlockData plane, x, y, 'landscape items'
            N = settings.mapBlockSizeInCells
            blockx = x - N * Math.floor x/N
            blocky = y - N * Math.floor y/N
            for item in items
                if @pointsAreClose item.position[0], item.position[1], \
                        blockx, blocky
                    item.position = [ blockx, blocky ]
                    item.type = type
                    item.behaviors =
                        JSON.parse JSON.stringify( behaviors or [ ] )
                    @setBlockData plane, x, y, 'landscape items', items
                    return yes
            no

To move a landscape item, we must do a few things.  First, ensure that there
is not another landscape item at the location to which we want to move the
given one.  Then put a new item with the same data at the new location while
deleting the old item.  Return true on success, false on failure.

        moveLandscapeItem : ( oldItem, newPlane, newX, newY ) =>
            @removeLandscapeItem oldItem.position...
            success = @addLandscapeItem newPlane, newX, newY, oldItem.type
            if success
                oldItem.setPosition newPlane, newX, newY
            else
                @addLandscapeItem oldItem.position..., oldItem.type
            oldItem.save()
            success

This function checks all blocks touching the current one and finds all
landscape items whose rectangle includes the given map coordinates.  The
limitation here is that this can only be called on blocks that are visible
to some player, because it returns actual `LandscapeItem` instances, which
only exist in cached blocks, and only visible blocks are cached.

        getItemsOverPoint : ( plane, x, y ) =>
            corner = ( parseInt i for i in \
                @positionToBlockName( plane, x, y ).split ',' )
            corner = x : corner[1], y : corner[2]
            N = settings.mapBlockSizeInCells
            results = [ ]
            typetable = require './landscapeitems'
            for i in [corner.x-N,corner.x,corner.x+N]
                for j in [corner.y-N,corner.y,corner.y+N]
                    bname = module.exports.positionToBlockName plane, i, j
                    for item in @landscapeItems[bname] ? [ ]
                        if Math.abs( x - item.x ) < item.size/2 and \
                           Math.abs( y - item.y ) < item.size/2
                            results.push item
            results

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
            cellTypeChooser = require( './celltypes' ).entryChooser player,
                'Default cell type', @get entry, 'default cell type'
            do again = => player.showUI
                type : 'text'
                value : "<h3>Editing #{entry}:</h3>"
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
                cellTypeChooser( again )
            ,
                type : 'action'
                value : 'Teleport to this plane'
                action : =>
                    plane = @indexOfPlaneKey entry
                    player.teleport [ plane, 0, 0 ]
                    # no need to change UI at all
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : ( event ) =>
                    @set entry, 'default cell type',
                        event['Default cell type']
                    callback()

A maker can remove an entry if and only if it is a plane that that maker can
edit.

        canRemove : ( player, entry ) =>
            @isPlaneKey( entry ) and @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove #{entry} <i>permanently</i>.  This action
                 <i>cannot</i> be undone!", action, callback

## Block Caching

We also override the cache-clearing function so that it does not pay
attention only to cache size, but rather it keeps in the cache just those
blocks that are visible to players.

        clearCache : =>
            for entryName in Object.keys @cache.entries
                if playersWhoCanSeeBlock[entryName]?.length is 0
                    @removeFromCache entryName

Whenever a block is added to the cache, we ensure that instances of the
LandscapeItem class are constructed for all its landscape items.

        putIntoCache : ( entryName, entry, entrySize ) =>
            @landscapeItems ?= { }
            super entryName, entry, entrySize
            { LandscapeItem } = require './landscapeitems'
            for item in entry['landscape items'] or [ ]
                [ plane, x, y ] =
                    ( parseInt i for i in entryName.split( ',' ) )
                x += item.position[0]
                y += item.position[1]
                ( @landscapeItems[entryName] ?= [ ] ).push \
                    new LandscapeItem plane, x, y

When a block is removed from the cache, we destroy all the landscape item
instances that go with it.

        removeFromCache : ( entryName ) =>
            super entryName
            for item in ( @landscapeItems ?= { } )[entryName] ? [ ]
                require( './behaviors' ).clearIntervalSet \
                    item.intervalSetIndex
            delete ( @landscapeItems ?= { } )[entryName]

To reset a block to its initial state (reloading all landscape items and
their behaviors) we just remove it from the cache and re-add it.

        resetBlock : ( blockName ) =>
            @removeFromCache blockName
            @get blockName

Export a singleton of the class as the module.

    module.exports = new BlocksTable

## Movement and Visibility

Is a given map location a valid place for a player or creature to stand?
This function answers that question.  The position must be a plane,x,y
triple, and the second parameter a player or creature object.

    module.exports.validPosition = ( position, who ) ->
        if not position then return yes
        [ plane, x, y ] = position
        celltype = module.exports.getCell plane, x, y
        if celltype is -1
            celltype = module.exports.get module.exports.planeKey( plane ),
                'default cell type'
        require( './celltypes' ).canWalkOn who, celltype

Here is a function that computes, for a given point on the map, the name of
the block containing that point.  A block name is the point at the top-left
corner of the block.

    blockName = module.exports.blockName = ( position ) ->
        size = settings.mapBlockSizeInCells
        x = size * Math.floor position[1] / size
        y = size * Math.floor position[2] / size
        [ position[0], x, y ]

Below we have a function that's called by the player object for any player
that moves.  We use it to update the above two mappings, so that this module
can send information to clients about what's moving on their screen.  But
first we need the function we'll use to send the notification to clients.

    notifyAboutMovement = ( notifyThisPlayer, aboutThisPlayer, position ) ->
        if notifyThisPlayer is aboutThisPlayer then return
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
            c = settings.mapBlockSizeInCells
            plane = p[0]
            x = p[1] - visionDistance
            while x < p[1] + visionDistance + c
                y = p[2] - visionDistance
                while y < p[2] + visionDistance + c
                    visibleBlocks.push "#{blockName [ plane, x, y ]}"
                    y += c
                x += c

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
                    if array.length is 0
                        delete playersWhoCanSeeBlock[block]

Next, for any block that was recently invisible but became visible, add the
player to its entry in `playersWhoCanSeeBlock`.  Also, notify the player of
the locations of anyone in that block, since they can now see it.

        for block in visibleBlocks
            if block not in formerlyVisibleBlocks
                blockSetChanged = yes
                playersWhoCanSeeBlock[block] ?= [ ]
                for otherPlayer in playersWhoCanSeeBlock[block]
                    if not otherPlayer = Player.nameToPlayer otherPlayer
                        continue
                    theirBlock = "#{blockName otherPlayer.getPosition()}"
                    if theirBlock is block
                        notifyAboutMovement player, otherPlayer,
                            otherPlayer.getPosition()
                playersWhoCanSeeBlock[block].push player.name

Now notify all players who could see the player's current or former block
that the player moved.

        toNotify = if oldPosition
            playersWhoCanSeeBlock[blockName oldPosition] ? [ ]
        else
            [ ]
        maybeMore = if p
            playersWhoCanSeeBlock[blockName p] ? [ ]
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

Finally, for all landscape items in all visible blocks, check to see if the
player just entered it.

        if p
            playerTopLeft = x : p[1] - 0.25, y : p[2] - 0.75
            playerBottomRight = x : p[1] + 0.25, y : p[2]
            playerPlane = p[0]
        else
            playerTopLeft = playerBottomRight = playerPlane = null
        if oldPosition
            previousTopLeft =
                x : oldPosition[1] - 0.25, y : oldPosition[2] - 0.75
            previousBottomRight =
                x : oldPosition[1] + 0.25, y : oldPosition[2]
            previousPlane = oldPosition[0]
        else
            previousTopLeft = previousBottomRight = previousPlane = null
        blocksToCheck = visibleBlocks.slice()
        for block in formerlyVisibleBlocks
            if block not in blocksToCheck
                blocksToCheck.push block
        for block in blocksToCheck
            for item in module.exports.landscapeItems?[block] or [ ]
                old = previousTopLeft and previousBottomRight and \
                    item.plane is previousPlane and \
                    item.collides previousTopLeft, previousBottomRight
                now = playerTopLeft and playerBottomRight and \
                    item.plane is playerPlane and \
                    item.collides playerTopLeft, playerBottomRight
                if old and not now then item.emit 'exited', player
                if now and not old then item.emit 'entered', player

The following function notifies players about their set of visible blocks.
Each block is shallow-copied, so that manipulations to it can be made if
needed before sending to the player.  For instance, for non-maker players,
any landscape items visible only to makers get filtered out.

    notifyAboutVisibility = ( notifyThisPlayer, blockSet ) ->
        if not notifyThisPlayer then return
        blockSet ?= blocksVisibleToPlayer[notifyThisPlayer.name]
        data = { }
        for block in blockSet
            [ plane, x, y ] = ( parseInt i for i in block.split ',' )
            data[block] = { }
            for own key, value of module.exports.getBlock plane, x, y
                data[block][key] = value
            if not notifyThisPlayer.isMaker()
                itemtypes = [ ]
                for item in data[block]['landscape items'] ? [ ]
                    itemtypes.push item.type if item.type not in itemtypes
                visibleItems = [ ]
                for type in itemtypes
                    if require( './landscapeitems' ).get type, 'visible'
                        for item in data[block]['landscape items'] ? [ ]
                            visibleItems.push item if item.type is type
                data[block]['landscape items'] = visibleItems
            data[block]['movable items'] =
                module.exports.getMovableItemsInBlock block
            data[block]['creatures'] = ( creature.forClient() \
                for creature in module.exports.getCreaturesInBlock block )
        notifyThisPlayer.socket.emit 'visible blocks', data
        for block in blockSet
            require( './animations' ).sendBlockAnimationsToPlayer block,
                notifyThisPlayer

And when a block is edited by a maker, we want to call the above function on
every player who can see the block.

    module.exports.notifyAboutBlockUpdate = ( blockName ) ->
        for playerName in playersWhoCanSeeBlock?[blockName] ? [ ]
            player = Player.nameToPlayer playerName
            if player then notifyAboutVisibility player

For a creature or movable item that was updated, we do not always need to
re-send the data of all blocks, a waste of bandwidth.  For instance, if a
creature moves within a block, we can just send its new state and let the
client insert that into the last-transmitted data about all blocks.  (This
is only true of creatures and movable items because only they have unique
IDs, which this necessitates.)  Note that if a creature moves between
blocks, this will not function as expected; in that case, use the previous
function instead.

    module.exports.notifyAboutCreatureUpdate = ( creatureObject ) ->
        block =
            module.exports.positionToBlockName creatureObject.location...
        for playerName in playersWhoCanSeeBlock?[block] ? [ ]
            player = Player.nameToPlayer playerName
            if player then player.socket.emit 'creature instance update',
                block : block
                creature : creatureObject.forClient()
    module.exports.notifyAboutMovableItemUpdate = ( itemObject ) ->
        block = module.exports.positionToBlockName itemObject.location...
        for playerName in playersWhoCanSeeBlock?[block] ? [ ]
            player = Player.nameToPlayer playerName
            if player then player.socket.emit \
                    'movable item instance update',
                block : block
                item : itemObject

Makers have a reset command that reloads all the blocks near the maker.
That command calls the following function.

    module.exports.resetBlocksNearPlayer = ( player ) =>
        for block in blocksVisibleToPlayer[player.name]
            for item in module.exports.getMovableItemsInBlock block
                item.destroy()
            for creature in module.exports.getCreaturesInBlock block
                creature.destroy()
            module.exports.resetBlock block

Which players (and later creatures) can see a certain position on the game
map?  This will be useful for sending events such as "heard someone speak."

    module.exports.whoCanSeePosition = ( position ) =>
        if position not instanceof Array then return [ ]
        bname = module.exports.positionToBlockName position...
        results = [ ]
        for playerName in playersWhoCanSeeBlock[bname] ? [ ]
            player = Player.nameToPlayer playerName
            if player then results.push player
        N = settings.mapBlockSizeInCells
        for dx in [-N,0,N]
            for dy in [-N,0,N]
                bname = module.exports.positionToBlockName \
                    [ position[0], position[1]+dx, position[2]+dy ]
                results = results.concat \
                    module.exports.getCreaturesInBlock bname
        results

## Movable Items

One global data structure stores the set of movable items in a given block.
This is stored separate from the blocks themselves, because it should not be
preserved across runs of the game.  It will, however, persist even while
blocks are loaded and unloaded -- which is nice!

    movableItemsInBlock = { }
    movableItemData = { }

This function adds a movable item to the map, categorizing them by block.
It does not update the item's internal data structure; see the item's own
`move()` function for that.  In fact, `move()` calls this function, so do
not call this function yourself; call `move()` instead.

    module.exports.addMovableItemToMap = ( item, location ) ->
        if bname = module.exports.positionToBlockName location...
            movableItemsInBlock[bname] ?= { }
            movableItemsInBlock[bname][item.ID] = item
            movableItemData[item.ID] =
                block : bname
                lastTouched : new Date
            module.exports.notifyAboutBlockUpdate bname

This function removes a movable item from the map.  Again, it does not alter
the item's own data; use the item's `move()` function for that.  In fact,
`move()` calls this function, so do not call this function yourself; call
`move()` instead.  The item parameter can be an object or a unique ID.

    module.exports.removeMovableItemFromMap = ( item ) ->
        if typeof item isnt 'number' then item = item.ID
        if bname = movableItemData[item]?.block
            delete movableItemsInBlock[bname][item]
            delete movableItemData[item]
            module.exports.notifyAboutBlockUpdate bname

This function fetches the contents of a block as an array for use in sending
to players who can see the block.

    module.exports.getMovableItemsInBlock = ( bname ) ->
        result = [ ]
        result.push item for own id, item of movableItemsInBlock[bname] ? []
        result

In order that items may disappear after sitting in the world for a certain
period of time, we have the following function, which clears the above data
structures of stale items.

    cleanUpOldMovableItems = ->
        now = new Date
        lifespan = settings.movableItemLifespanInSeconds * 1000
        toCleanUp = [ ]
        for id, data in movableItemData
            if now - data.lastTouched > lifespan
                toRemove.push movableItemsInBlock[data.bname][id]
        item.destroy() for item in toCleanUp

Call the above cleanup function 10 times per item lifespan.

    setInterval cleanUpOldMovableItems,
        settings.movableItemLifespanInSeconds * 100

And a public API for getting the list of items near a specific point on the
map.  How near is given in the second argument, and is measured in units of
map cells.

    module.exports.movableItemsNearPosition = ( position, radius ) ->
        extremes = [
            [ position[0], position[1]-radius, position[2]-radius ]
            [ position[0], position[1]-radius, position[2]+radius ]
            [ position[0], position[1]+radius, position[2]-radius ]
            [ position[0], position[1]+radius, position[2]+radius ]
        ]
        distance = ( x1, y1, x2, y2 ) ->
            Math.sqrt ( x1 - x2 ) * ( x1 - x2 ) + ( y1 - y2 ) * ( y1 - y2 )
        blocks = [ ]
        for point in extremes
            bname = module.exports.positionToBlockName point...
            if bname not in blocks then blocks.push bname
        results = [ ]
        for bname in blocks
            for own id, item of movableItemsInBlock[bname] ? { }
                if distance( item.location[1], item.location[2],
                             position[1], position[2] ) < radius
                    results.push item
        results

## Creatures

Just as with movable items, we have one global data structure that tracks
the set of creatures each block.  This is stored separate from the blocks
themselves, because it should not be preserved across runs of the game.  It
will, however, persist even while blocks are loaded and unloaded -- which is
nice!

    creaturesInBlock = { }
    creatureData = { }

This function adds a creature to the map, categorizing them by block.  It
does not update the creature's internal data structure; see the creature's
own `move()` function for that.  In fact, `move()` calls this function, so
do not call this function yourself; call `move()` instead.

    module.exports.moveCreature = ( creature, newLocation ) ->
        if newLocation isnt null
            if not module.exports.validPosition newLocation, creature
                return no
            if not newbname = \
                    module.exports.positionToBlockName newLocation...
                return no
        if typeof creature is 'number'
            id = creature
            creature = require( './creatures' ).Creature::creatureForID id
        else
            id = creature.ID
        lastSeen = new Date
        if oldbname = creatureData[id]?.block
            delete creaturesInBlock[oldbname][id]
            lastSeen = creatureData[id].lastSeen
            delete creatureData[id]
        if newLocation isnt null
            creaturesInBlock[newbname] ?= { }
            creaturesInBlock[newbname][id] = creature
            if ( playersWhoCanSeeBlock[newbname] ? [ ] ).length > 0
                lastSeen = new Date
            creatureData[id] = block : newbname, lastSeen : lastSeen
        if oldbname and oldbname is newbname
            module.exports.notifyAboutCreatureUpdate creature
        else
            if newbname then module.exports.notifyAboutBlockUpdate newbname
            if oldbname then module.exports.notifyAboutBlockUpdate oldbname
        yes

This function fetches the contents of a block as an array for use in sending
to players who can see the block.

    module.exports.getCreaturesInBlock = ( bname ) ->
        result = [ ]
        for own id, creature of creaturesInBlock[bname] ? []
            result.push creature
        result

In order that creatures may disappear after being unseen for a certain
period of time, we have the following function, which clears the above data
structures of stale items.

    cleanUpOldCreatures = ->
        now = new Date
        lifespan = settings.creatureLifespanInSeconds * 1000
        toCleanUp = [ ]
        for id, data in creatureData
            if ( playersWhoCanSeeBlock[data.block] ? [ ] ).length > 0
                data.lastSeen = now
            else if now - data.lastSeen > lifespan
                toRemove.push creaturesInBlock[data.bname][id]
        creature.destroy() for creature in toCleanUp

Call the above cleanup function 10 times per creature lifespan.

    setInterval cleanUpOldCreatures,
        settings.creatureLifespanInSeconds * 100

And a public API for getting the list of creatures near a specific point on
the map.  How near is given in the second argument, and is measured in units
of map cells.

    module.exports.creaturesNearPosition = ( position, radius ) ->
        if not position? then return [ ]
        extremes = [
            position
            [ position[0], position[1]-1, position[2] ]
            [ position[0], position[1]+1, position[2] ]
            [ position[0], position[1], position[2]-1 ]
            [ position[0], position[1], position[2]+1 ]
        ]
        distance = ( x1, y1, x2, y2 ) ->
            Math.sqrt ( x1 - x2 ) * ( x1 - x2 ) + ( y1 - y2 ) * ( y1 - y2 )
        blocks = [ ]
        for point in extremes
            bname = module.exports.positionToBlockName point...
            if bname not in blocks then blocks.push bname
        results = [ ]
        for bname in blocks
            for own id, creature of creaturesInBlock[bname] ? { }
                if distance( creature.location[1], creature.location[2],
                             position[1], position[2] ) < radius
                    results.push creature
        results
