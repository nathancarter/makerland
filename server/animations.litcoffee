
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
                        type : 'text'
                        value : '<p>Not sure how to write this code?
                            <a href="docs/animationcoding.html"
                            target="_blank">Click here</a> to open some
                            instructions (in a new tab).</p>'
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

The following function stores in this table's temporary memory the fact that
an animation of the given type has just started; the given parameters and
location are stored with it.  Immediately thereafter, any players who can
see the block in which the animation just began will have their block data
updated, so that their clients receive the information about the animation.
(The block table, before sending block data to players, queries this table,
to see if any running animations need to be sent as well.)

        showAnimation : ( location, animationType, parameterObject ) =>
            if not @namesToIndices?
                @namesToIndices = { }
                for entry in @entries()
                    @namesToIndices[@get entry, 'name'] = entry
            if @namesToIndices.hasOwnProperty animationType
                animationType = @namesToIndices[animationType]
            if not animationType? then return
            animation = @getWithDefaults animationType
            if not animation?
                return console.log "Could not find animation type
                    \"#{animationType}\" in database -- cannot show."
            @runningAnimations ?= { }
            if typeof location is 'string'
                location = ( parseFloat i for i in location.split ',' )
            bt = require './blocks'
            blockName = bt.positionToBlockName location...
            ( @runningAnimations[blockName] ?= [ ] ).push
                type : animationType
                definition : animation
                parameters : parameterObject
                startTime : new Date
            bt.notifyAboutBlockUpdate blockName

The block table, when it sends data to players about what blocks they can
see, will want this table to be able to send animation data.  The block
table will call the following function, and we will send the players all the
information they need.  Note that we only send the player the definition of
an animation (from the table) if that player doesn't already have it, a flag
we track in the player object.  This function also removes from the list any
animations that have completed; it does so before sending any to the player,
of course.

        sendBlockAnimationsToPlayer : ( blockName, playerObject ) =>
            toSend = [ ]
            ( @runningAnimations ?= { } )[blockName] ?= [ ]
            now = new Date
            stillRunning = ( anim ) =>
                later = new Date anim.startTime.getTime() \
                      + anim.definition.duration * 1000
                later > now
            @runningAnimations[blockName] = ( anim for anim in \
                @runningAnimations[blockName] when stillRunning anim )
            for animation in @runningAnimations[blockName]
                elapsed = now - animation.startTime
                record =
                    type : animation.type
                    parameters : animation.parameters
                    elapsed : elapsed
                if not playerObject.animationCache?[animation.type]
                    record.definition = animation.definition
                    ( playerObject.animationCache ?= { } )[animation.type] \
                        = true
                toSend.push record
            if @runningAnimations[blockName].length is 0
                delete @runningAnimations[blockName]
            playerObject.socket.emit 'animations for block',
                block : blockName
                animations : toSend

If the animation is updated, we need to clear out the cached version of its
former state in all clients.  The following function does so.

        set : ( entryName, others... ) =>
            super entryName, others...
            if @namesToIndices
                @namesToIndices[@get entryName, 'name'] = entryName
            for player in Player::allPlayers
                if player.animationCache
                    delete player.animationCache[entryName]

## Exporting

The module then exports a single instance of the `BehaviorsTable` class.

    module.exports = new AnimationsTable
