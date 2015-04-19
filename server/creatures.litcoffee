
# Creatures

Technically, this table is a list of the *types* of creatures that can be
encountered in the game, and thus for consistency should possibly be named
`creaturetypes`, but it's been copied from movable items, so I stuck with
that type of consistency instead.

Creatures cannot be held by players or put into containers.  In some sense,
they're like moving landscape items.  Their locations on the map are not
necessarily integer coordinates, again, just like landscape items.

## Creature Class

We now create a class for embodying creatures as they walk around the game
world, in blocks that are currently loaded.

    class Creature

All instances of the class will be kept in a global array, whose indices
give them a unique ID.

        allCreatures : [ ]

We can therefore look up an instance based on its ID.

        creatureForID : ( id ) -> Creature::allCreatures[id]

At construction time, we must be told which type of creature we are.  Our
location will initially be null.  Later, we can be moved to a map point by
calling our `move()` method.

        constructor : ( @index ) ->
            @location = null
            if @type = module.exports.getWithDefaults @index
                @typeName = @type.name
                @behaviors = @type.behaviors
            for behavior in @behaviors ?= [ ]
                require( './behaviors' ).installBehavior behavior, this

Now place the creature into the global instances array and store within the
creature its index in that array as its unique ID.

            for creature, index in Creature::allCreatures
                if creature is null
                    @ID = index
                    Creature::allCreatures[index] = this
            if not @ID?
                @ID = Creature::allCreatures.length
                Creature::allCreatures.push this

We therefore create a corresponding "destructor" which should be called to
prepare this creature for garbage collection, such as when the creature
dies.  This function moves the creature out of the global instances array,
thus removing the most important pointer to the object.  Assuming no
one else retains a pointer to this object, it will be garbage collected
hereafter.

        destroy : =>
            @move null
            if @ID
                Creature::allCreatures[@ID] = null
                @ID = null

This function moves creatures to a new location.  It not only updates this
object's own internal `@location` field, but also notifies the former/next
map blocks, if any, to update their own contents, to stay consistent with
this creature's location.  This is the official way to move a creature while
keeping all data consistent throughout the game.  If the new location is
invalid, then `null` will be used instead.

        move : ( newLocation ) =>
            @location = newLocation
            if not require( './blocks' ).moveCreature this, newLocation
                @location = null

Mix handlers into `Creature`s.

    require( './handlers' ).mixIntoClass Creature

## Creatures Table

Most of this module is a database table, so we require the table module,
plus some others.

    { Table } = require './table'
    { Player } = require './player'
    fs = require 'fs'
    path = require 'path'

It subclasses the main Table class and adding creature-specific
functionality.

    class CreaturesTable extends Table

## Table Constructor

        constructor : () ->

First, give the table its name and set default values for keys.

            super 'creatures'

## Maker Database Browsing

Implement custom show method.

        show : ( entry ) =>
            "<p>#{entry}. #{@smallIcon entry} #{@get( entry ).name}</p>"

Ensure entries are returned sorted in numerical order.

        entries : => super().sort ( a, b ) -> parseInt( a ) - parseInt( b )

Whenever an entry in the table changes, notify all players to update their
client-side creature caches.

        set : ( entryName, others... ) =>
            super entryName, others...
            for p in Player::allPlayers
                p.socket.emit 'creature changed', entryName

## Maker Permissions

Any maker can add new entries to the table.  The UI for doing so looks like
the following.

        canAdd : -> yes
        add : ( player, callback = -> player.showCommandUI() ) =>
            entries = @entries()
            i = 1
            while "#{i}" in entries
                i++
            @set "#{i}", name : 'new creature'
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new creature was created with index #{i}.
                You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

Who can edit individual entries in the creatures table is determined by the
authors list, which is the default implementation of `canEdit` in the
`Table` class.

The UI for editing a movable item looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h3>Editing creature #{entry}:</h3>"
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
                            value : "<h3>Changing name of creature
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new creature name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new creature name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of creature #{entry}
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
                            "A single map cell is an image of size
                            #{N}x#{N}.  Creatures will be shown at their
                            full resolution, so do not upload large images
                            if you do not intend the creatures themselves
                            to be correspondingly large.  Before uploading
                            an icon, consider resizing it on your computer,
                            to save bandwidth and keep the game server
                            responsive.",
                            again, ( contents ) =>
                                @setFile entry, 'icon', contents
                ]
            ,
                type : 'action'
                value : 'Edit behaviors'
                action : =>
                    creature = new Creature entry, null
                    require( './behaviors' ).editAttachments player, item,
                        =>
                            @set entry, 'behaviors', creature.behaviors
                            again()
            ,
                type : 'action'
                value : 'Spawn one at my location'
                action : =>
                    creature = new Creature entry
                    creature.move player.getPosition()
                    player.showOK "An instance of creature #{entry},
                        \"#{@get entry, 'name'},\" has been spawned at your
                        location.", again
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback

A maker can remove a creature type if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the creature #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 instances of this creature in the game map, they will
                 (sooner or later) disappear and/or stop functioning!",
                 action, callback

## Exporting

The module then exports a single instance of the `CreaturesTable` class,
and the `Creature` class as an attribute thereof.

    module.exports = new CreaturesTable
    module.exports.Creature = Creature
