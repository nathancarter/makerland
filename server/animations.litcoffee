
# Animations Table

This module implements a game database table for storing animations, which
are blocks of code that can be run on the client to add animated effects on
top of the game map.

    { Table } = require './table'
    { Player } = require './player'

It does so by subclassing the main Table class and adding behavior-specific
functionality.

    class AnimationsTable extends Table

## Constructor

The constructor just sets the name of the table, then some defaults.

        constructor : () ->
            super 'animations'
            @setDefault 'duration', 1

## Maker Database Browsing

Implement custom show method.

        show : ( entry ) => "<p>#{entry}. #{@get( entry ).name}</p>"

Ensure entries are returned sorted in numerical order.

        entries : => super().sort ( a, b ) -> parseInt( a ) - parseInt( b )

## Maker Permissions

Any maker can add new entries to the table.  The UI for doing so looks like
the following.

        canAdd : -> yes
        add : ( player, callback = -> player.showCommandUI() ) =>
            entries = @entries()
            i = 1
            while "#{i}" in entries
                i++
            @set "#{i}", name : 'new animation'
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new animation was created with index #{i}.
                You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

You can edit an animation if you're one of its authors, which is the default
implementation of `canEdit`, so we have no need to override that.  The UI
for doing so looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            data = @getWithDefaults entry
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h3>Editing animation #{entry},
                    \"#{data.name}\":</h3>"
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
                            value : "<h3>Changing name of animation
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new animation name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new animation name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of animation #{entry}
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
                [
                    type : 'text'
                    value : 'Duration:'
                ,
                    type : 'text'
                    value : "#{data.duration} (seconds)"
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing duration of animation
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'enter duration in seconds'
                        ,
                            type : 'text'
                            value : '<p>(For example, enter 1 or 6.5.  Do
                                not include units.)'
                        ,
                            type : 'action'
                            value : 'Change duration'
                            default : yes
                            action : ( event ) =>
                                input = event['enter duration in seconds'] \
                                    .trim()
                                if isFinite input \
                                   and not isNaN parseFloat input
                                    @set entry, 'duration', parseFloat input
                                    player.showOK "Duration of animation
                                        #{entry} changed to #{input}.",
                                        again
                                else
                                    player.showOK 'New duration must be only
                                        a number.  Do not include any words
                                        or units.', again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ,
                type : 'text'
                value : 'Description:'
            ,
                type : 'text'
                value : "<div class='well'>
                         #{data.description or '(no description yet)'}
                         </div>"
            ,
                type : 'action'
                value : 'Edit description'
                action : =>
                    player.showUI
                        type : 'text'
                        value : "<h3>Changing description of animation
                            #{entry}:</h3>"
                    ,
                        type : 'text input'
                        name : 'new description'
                        value : data.description
                    ,
                        type : 'action'
                        value : 'Save changes'
                        action : ( event ) =>
                            newdesc = event['new description']
                            if not /[a-z]/.test newdesc
                                return player.showOK 'Description must
                                    contain at least one letter.', again
                            @set entry, 'description', newdesc
                            again()
                    ,
                        type : 'action'
                        value : 'Cancel'
                        cancel : yes
                        action : again
            ,
                type : 'action'
                value : 'Edit implementation'
                action : =>
                    player.showUI
                        type : 'text'
                        value : "<h3>Changing implementation of animation
                            #{entry}:</h3>"
                    ,
                        type : 'code input'
                        name : 'new implementation'
                        value : data.code
                    ,
                        type : 'action'
                        value : 'Save changes'
                        action : ( event ) =>
                            newcode = event['new implementation']
                            @set entry, 'code', newcode
                            again()
                    ,
                        type : 'action'
                        value : 'Cancel'
                        cancel : yes
                        action : again
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback

A maker can remove an animation if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the animation #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 events in the game that trigger this animation, it will
                 stop working!", action, callback

The following function sends to all relevant players a message indicating
that an animation is happening near them.  It provides those players'
clients with all the information they need to show the animation on those
players' screens.

        namesToIndices = null
        showAnimation : ( location, animationType, parameterObject ) =>
            if not namesToIndices
                namesToIndices = { }
                for entry in @entries()
                    namesToIndices[@get entry, 'name'] = entry
            if namesToIndices.hasOwnProperty entry
                entry = namesToIndices[entry]
            if not entry? then return
            animation = @get entry
            bt = require './blocks'
            for recipient in bt.getPlayersWhoCanSeeBlock location
                if not recipient.animationCache?[entry]
                    recipient.socket.emit 'animation data',
                        index : entry
                        data : animation
                    ( recipient.animationCache ?= { } )[entry] = true
                recipient.socket.emit 'show animation',
                    index : entry
                    data : parameterObject

If the animation is updated, we need to clear out the cached version of its
former state in all clients.  The following function does so.

        set : ( entryName, others... ) =>
            super entryName, others...
            if namesToIndices
                namesToIndices[@get entryName, 'name'] = entryName
            for player in Player::allPlayers
                if player.animationCache
                    delete player.animationCache[entryName]

## Exporting

The module then exports a single instance of the `BehaviorsTable` class.

    module.exports = new AnimationsTable
