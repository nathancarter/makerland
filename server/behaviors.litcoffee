
# Behaviors Table

This module implements a game database table for storing behaviors, which
are blocks of code that can be run to install functionality in a variety of
types of objects, such as landscape items.

    { Table } = require './table'

Behaviors come in a variety of types.  The following list will grow as new
types of behaviors are added to the game.

    behaviorTypeList = [
        'landscape item'
    ]

It does so by subclassing the main Table class and adding behavior-specific
functionality.

    class BehaviorsTable extends Table

## Constructor

The constructor just sets the name of the table.

        constructor : () ->
            super 'behaviors'

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
            @set "#{i}", name : 'new behavior'
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new behavior was created with index #{i}.
                You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

You can edit a behavior if you're one of its authors, which is the default
implementation of `canEdit`, so we have no need to override that.  The UI
for doing so looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            data = @get entry
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h3>Editing behavior #{entry},
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
                            value : "<h3>Changing name of behavior
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new behavior name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new behavior name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of behavior #{entry}
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
                    value : 'Applies to:'
                ,
                    type : 'text'
                    value : ( data.targets or [ ] ).join ', '
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        controls = [
                            type : 'text'
                            value : "<h3>Editing list of valid targets for
                                behavior #{entry}, #{data.name}:</h3>"
                        ]
                        for type in behaviorTypeList
                            controls.push
                                type : 'checkbox'
                                name : type
                                checked : type in ( data.targets or [ ] )
                        controls = controls.concat [
                            type : 'action'
                            value : 'Save changes'
                            default : yes
                            action : ( event ) =>
                                @set entry, 'targets', ( type for type in \
                                    behaviorTypeList when event[type] )
                                again()
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                        ]
                        player.showUI controls
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
                        value : "<h3>Changing description of behavior
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
                        value : "<h3>Changing implementation of behavior
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

A maker can remove a behavior if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the behavior #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 objects using this behavior in the game, they will no
                 longer have this functionality!", action, callback

## Exporting

The module then exports a single instance of the `BehaviorsTable` class.

    module.exports = new BehaviorsTable
