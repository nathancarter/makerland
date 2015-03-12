
# Map Cell Types Table

This module implements a game database table for storing types of map cells
(e.g., grassland, water, cobblestone path, etc.).

    { Table } = require './table'
    hash = require 'password-hash'

It does so by subclassing the main Table class and adding cell-type-specific
functionality.

    class CellTypesTable extends Table

## Constructor

Just give the table its name.

        constructor : () ->
            super 'celltypes'

## Maker Database Browsing

        show : ( entry ) -> "<p>#{entry}. #{@get( entry ).name}</p>"

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
                Feel free to edit it to suit your needs.", callback

Who can edit individual entries in the cell types table is determined by the
authors list, which is the default implementation of `canEdit` in the
`Table` class.

The UI for editing a cell type looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            data = @get entry
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h4>Editing cell type #{entry}:</h4>"
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
                    action : => require( './ui' ).editAuthorsList player,
                        this, entry, again
                ]
            ,
                type : 'action'
                value : 'Done'
                action : callback

A maker can remove a cell type if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the cell type #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!", action, callback

## Exporting

The module then exports a single instance of the `CellTypesTable` class.

    module.exports = new CellTypesTable()
