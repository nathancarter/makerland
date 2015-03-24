
# Landscape Items

Technically, this table is a list of the *types* of landscape items that can
be placed on the map, and thus for consistency should possibly be named
`landscapeitemtypes`, but that's just too long a module name.

Landscape items sit on top of the map and are not necessarily at integer
coordinates, nor equally spaced, nor arranged one per cell (trees, rocks,
signs, etc.).

## Landscape Items Class

We now create a class for embodying those landscape items which exist in
blocks of the map that are currently loaded.

    class LandscapeItem

At construction time, store the name of the block in which we live, and
compute our size based on our type, then our top-left and bottom-right
corners as well.

        constructor : ( @plane, @x, @y ) ->
            blockTable = require './blocks'
            @block = blockTable.positionToBlockName @plane, @x, @y
            if tableEntry = blockTable.getLandscapeItem @plane, @x, @y
                @type = tableEntry.type
                @behaviors = tableEntry.behaviors or [ ]
            @typeName = require( './landscapeitems' ).get @type, 'name'
            N = require( './settings' ).mapBlockSizeInCells
            @localX = @x - N * Math.floor @x/N
            @localY = @y - N * Math.floor @y/N
            @size = module.exports.get @type, 'size'
            @topLeft = x : @x - @size/2, y : @y - @size/2
            @bottomRight = x : @x + @size/2, y : @y + @size/2
            for behavior in @behaviors ?= [ ]
                require( './behaviors' ).installBehavior behavior, this

This utility tests whether an object at a given position is bumping into
this landscape item.  The object's position is given by a rectangular
bounding box.  The `rectanglesCollide` function is general, and just happens
to be placed here.  The `@collides` function is the one that matters for
landscape items.

        rectanglesCollide : ( x1, y1, x2, y2, x3, y3, x4, y4 ) ->
            not ( x3 > x2 or x4 < x1 or y3 > y2 or y4 < y1 )
        collides : ( topLeft, bottomRight ) =>
            @rectanglesCollide @topLeft.x, @topLeft.y,
                @bottomRight.x, @bottomRight.y, topLeft.x, topLeft.y,
                bottomRight.x, bottomRight.y

Landscape items can also save themselves to disk, by writing to the block in
which they sit.  This is done through a special method provided by the
blocks table.  We just pass this object, and that method reads all the
necessary data (including its global position as a unique ID) out of this
object's members.

        save : => require( './blocks' ).setLandscapeItem this

Mix handlers into `LandscapeItem`s.

    require( './handlers' ).mixIntoClass LandscapeItem

## Landscape Items Table

Most of this module is a database table, so we require the table module,
plus some others.

    { Table } = require './table'
    { Player } = require './player'
    fs = require 'fs'
    path = require 'path'

It subclasses the main Table class and adding landscape-item-specific
functionality.

    class LandscapeItemsTable extends Table

## Table Constructor

        constructor : () ->

First, give the table its name and set default values for keys.

            super 'landscapeitems', 'Landscape Items'
            @setDefault 'size', 1.0
            @setDefault 'visible', yes

Then if there are no entries in it (i.e., this is the first time it's been
loaded) then pre-populate it with some simple invisible squares for use by
makers.

            if @entries().length is 0
                icon = fs.readFileSync path.resolve \
                    'client/icons/square.png'
                for i in [ 0, 1, 2 ]
                    size = [ 'small', 'normal', 'large' ][i]
                    @set i,
                        name : "#{size} invisible square"
                        size : [ 0.5, 1.0, 2.0 ][i]
                        visible : no
                    @setAuthors i, [ 'admin' ]
                    @setFile i, 'icon', icon

## Maker Database Browsing

Implement custom show method.

        show : ( entry ) =>
            "<p>#{entry}. #{@smallIcon entry} #{@get( entry ).name}</p>"

Ensure entries are returned sorted in numerical order.

        entries : => super().sort ( a, b ) -> parseInt( a ) - parseInt( b )

Whenever an entry in the table changes, notify all players to update their
client-side landscape item caches.

        set : ( entryName, others... ) =>
            super entryName, others...
            for p in Player::allPlayers
                p.socket.emit 'landscape item changed', entryName

## Maker Permissions

Any maker can add new entries to the table.  The UI for doing so looks like
the following.

        canAdd : -> yes
        add : ( player, callback = -> player.showCommandUI() ) =>
            entries = @entries()
            i = 1
            while "#{i}" in entries
                i++
            @set "#{i}", name : 'new landscape item'
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new landscape item was created with index
                #{i}.  You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

Who can edit individual entries in the landscape items table is determined
by the authors list, which is the default implementation of `canEdit` in the
`Table` class.

The UI for editing a landscape item looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h3>Editing landscape item #{entry}:</h3>"
            ,
                [
                    type : 'text'
                    value : 'Name:'
                ,
                    type : 'text'
                    value : @get entry, 'name'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing name of landscape item
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new landscape item name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new landscape item name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of landscape item
                                    #{entry} changed to #{newname}.", again
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
                [
                    type : 'text'
                    value : 'Size:'
                ,
                    type : 'text'
                    value : @get entry, 'size'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        require( './ui' ).pickFromList player,
                            "Choose a size for landscape item #{entry}.",
                            {
                                'small (half a cell)' : 0.5
                                'normal (1 cell)' : 1.0
                                'large (1.5 cells)' : 1.5
                                'very large (2 cells)' : 2.0
                                'huge (3 cells)' : 3.0
                            }, @get( entry, 'size' ),
                            ( choice ) =>
                                if choice then @set entry, 'size', choice
                                again()
                ]
            ,
                [
                    type : 'text'
                    value : 'Icon:'
                ,
                    type : 'text'
                    value : @smallIcon entry
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        N = require( './settings' ).cellSizeInPixels
                        player.getFileUpload "#{@get entry, 'name'} icon",
                            "Files of size #{N}x#{N} are just right for
                            landscape items that are 1 cell in size.  For
                            larger or smaller items, choose a different
                            file size accordingly.  Files that are too big
                            take up unnecessary space on the game server,
                            and will potentially flicker as you walk near
                            them.  Before uploading an icon, consider
                            resizing it on your computer to be #{N}x#{N}
                            for a one-cell landscape item, or another size
                            if your item needs it.",
                            again, ( contents ) =>
                                @setFile entry, 'icon', contents
                ]
            ,
                [
                    type : 'text'
                    value : 'Visible to players?'
                ,
                    type : 'text'
                    value : if @get entry, 'visible' then 'yes' else 'no'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        require( './ui' ).pickFromList player,
                            "Choose whether landscape item #{entry} is
                            visible to players.  Note that <i>makers</i>
                            can always see landscape items, even those that
                            ordinary players cannot.",
                            {
                                'yes' : true
                                'no' : false
                            }, @get( entry, 'name' ),
                            ( choice ) =>
                                if choice isnt null
                                    @set entry, 'visible', choice
                                again()
                ]
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback

A maker can remove a landscape item type if and only if that maker can edit
it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the landscpae item #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 instances of this landscape item in the game map, they
                 will disappear!", action, callback

## Exporting

The module then exports a single instance of the `LandscapeItemsTable`
class, and the `LandscapeItem` class as an attribute thereof.

    module.exports = new LandscapeItemsTable
    module.exports.LandscapeItem = LandscapeItem
