
# Map Cell Types Table

This module implements a game database table for storing types of map cells
(e.g., grassland, water, cobblestone path, etc.).

    { Table } = require './table'
    { Player } = require './player'
    ui = require './ui'

It does so by subclassing the main Table class and adding cell-type-specific
functionality.

    class CellTypesTable extends Table

## Constructor

Just give the table its name.  The default value of what kind of creatures
can walk on a cell type is "all."

        constructor : () ->
            super 'celltypes', 'Cell Types'
            @setDefault 'who can walk on it', 'all'
            @setDefault 'border color', '#000000'

Together with the property whose default was just set, we provide an API for
checking if a player can walk on a cell of a certain type.  Obviously, this
function is limited for now, as we only have two values for that property,
"none" and "all."  Later, this can become more complex.

        canWalkOn : ( player, type ) =>
            @get( type, 'who can walk on it' ) isnt 'none'

## Maker Database Browsing

Implement custom show method.

        show : ( entry ) =>
            "<p>#{entry}. #{@smallIcon entry} #{@get( entry ).name}</p>"

Ensure entries are returned sorted in numerical order.

        entries : => super().sort ( a, b ) -> parseInt( a ) - parseInt( b )

Whenever an entry in the table changes, notify all players to update their
client-side cell type caches.

        set : ( entryName, others... ) =>
            super entryName, others...
            for p in Player::allPlayers
                p.socket.emit 'cell data changed', entryName
        setFile : ( entryName, others... ) =>
            super entryName, others...
            for p in Player::allPlayers
                p.socket.emit 'cell data changed', entryName

## Maker Permissions

Any maker can add new entries to the table.  The UI for doing so looks like
the following.

        canAdd : -> yes
        add : ( player, callback = -> player.showCommandUI() ) =>
            entries = @entries()
            i = 1
            while "#{i}" in entries
                i++
            @set "#{i}", name : 'new cell type'
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new cell type was created with index #{i}.
                You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

Who can edit individual entries in the cell types table is determined by the
authors list, which is the default implementation of `canEdit` in the
`Table` class.

The UI for editing a cell type looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            data = @get entry
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h3>Editing cell type #{entry}:</h3>"
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
                            value : "<h3>Changing name of cell type
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new cell type name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new cell type name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of cell type #{entry}
                                    changed to #{newname}.", again
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
                    action : => ui.editAuthorsList player, this, entry,
                        again
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
                        player.getFileUpload "#{data.name} icon",
                            "Files larger than #{N}x#{N} will take up
                            unnecessary space on the game server, and will
                            potentially flicker as you walk over them.
                            Before uploading an icon, consider resizing it
                            on your computer to be #{N}x#{N}.",
                            again, ( contents ) =>
                                @setFile entry, 'icon', contents
                ]
            ,
                [
                    type : 'text'
                    value : 'Border size:'
                ,
                    type : 'text'
                    value : @get entry, 'border size'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        ui.pickFromList player,
                            "Choose border thickness.  Borders are only
                            drawn between this cell type and neighboring
                            cells of a <i>different</i> type.",
                            {
                                none : 0
                                thin : 0.5
                                medium : 1
                                thick : 2
                                huge : 3
                            },
                            @get( entry, 'border size' ),
                            ( result ) =>
                                if result
                                    @set entry, 'border size', result
                                again()
                ]
            ,
                [
                    type : 'text'
                    value : 'Border color:'
                ,
                    type : 'text'
                    value : "<font color='#{@get entry, 'border color'}'
                             >#{ui.colorName @get entry, 'border color'}
                             </font>"
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        ui.pickFromList player,
                            "Choose border color.  Note that borders will
                            be drawn only if you choose a thickness other
                            than \"none\" on the previous screen.",
                            ui.colors, @get( entry, 'border color' ),
                            ( result ) =>
                                if result
                                    @set entry, 'border color', result
                                again()
                ]
            ,
                [
                    type : 'text'
                    value : 'Who can walk on this?'
                ,
                    type : 'text'
                    value : @get entry, 'who can walk on it'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        ui.pickFromList player,
                            "Choose which kind of creatures can walk on
                            cells of type \"#{data.name}.\"",
                            { all : 'all', none : 'none' },
                            @get( entry, 'who can walk on it' ),
                            ( result ) =>
                                if result
                                    @set entry, 'who can walk on it', result
                                again()
                ]
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback

A maker can remove a cell type if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            ui.areYouSure player,
                "remove the cell type #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 instances of this cell type in the game map, they will
                 disappear!", action, callback

## Exporting

The module then exports a single instance of the `CellTypesTable` class.

    module.exports = new CellTypesTable
