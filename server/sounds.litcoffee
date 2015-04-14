
# Sounds Table

This module implements a game database table for storing sound effect and
music files.

    { Table } = require './table'
    { Player } = require './player'
    ui = require './ui'

It does so by subclassing the main Table class and adding sound-specific
functionality.

    class SoundsTable extends Table

## Constructor

Just give the table its name.

        constructor : () ->
            super 'sounds'

## Maker Database Browsing

Implement custom show method.

        show : ( entry ) =>
            size = @fileSize entry, 'soundfile'
            size = if size is -1 then '[no file]' else "#{(size/1024)|0}kB"
            "<p>#{entry}. #{@get( entry ).name} #{size}</p>"

Ensure entries are returned sorted in numerical order.

        entries : => super().sort ( a, b ) -> parseInt( a ) - parseInt( b )

Whenever an entry in the table changes, notify all players to update their
client-side sound caches.

        set : ( entryName, others... ) =>
            super entryName, others...
            for p in Player::allPlayers
                p.socket.emit 'sound data changed', entryName
        setFile : ( entryName, others... ) =>
            super entryName, others...
            for p in Player::allPlayers
                p.socket.emit 'sound data changed', entryName

## Maker Permissions

Any maker can add new entries to the table.  The UI for doing so looks like
the following.

        canAdd : -> yes
        add : ( player, callback = -> player.showCommandUI() ) =>
            entries = @entries()
            i = 1
            while "#{i}" in entries
                i++
            @set "#{i}", name : 'new sound'
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new sound was created with index #{i}.
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
            size = @fileSize entry, 'soundfile'
            size = if size is -1 then '[no file]' else "#{(size/1024)|0}kB"
            player.showUI
                type : 'text'
                value : "<h3>Editing sound #{entry}:</h3>"
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
                            value : "<h3>Changing name of sound
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new sound name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new sound name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of sound #{entry}
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
                    value : 'Sound file:'
                ,
                    type : 'text'
                    value : size
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.getFileUpload "#{data.name} sound file",
                            "Before uploading a sound file, be sure it is a
                            reasonable size.  Huge files take up bandwidth
                            and slow down the game.",
                            again, ( contents ) =>
                                @setFile entry, 'soundfile', contents
                ]
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback

A maker can remove a sound if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            ui.areYouSure player,
                "remove the sound #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 places or events in the game that use this sound,
                 they will go silent!", action, callback

## Playing Sounds

The function clients can use to play sounds takes a sound parameter (as an
index in this table or a name of an entry in this table) and a second
parameter of who should hear the sound. It can be a player object, in which
case just one player will hear the sound.  That player object is sent a
message so that its client will ask for the sound file and begin playing it.
Or instead the second parameter can be a location in the game world, in
which case all players who can see that location will hear the sound.

        playSound : ( entry, target ) =>
            if not @namesToIndices?
                @namesToIndices = { }
                for index in @entries()
                    @namesToIndices[@get index, 'name'] = index
            if @namesToIndices.hasOwnProperty entry
                entry = @namesToIndices[entry]
            if not @exists entry then return
            targets = if target instanceof Player then [ target ] else \
                require( './blocks' ).whoCanSeePosition target
            for target in targets
                target.socket.emit 'play sound', entry

## Exporting

The module then exports a single instance of the `SoundsTable` class.

    module.exports = new SoundsTable
