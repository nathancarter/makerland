
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
calling our `moveTo()` method.

        constructor : ( @index ) ->
            @location = null
            if @type = module.exports.getWithDefaults @index
                @typeName = @type.name
                @behaviors = @type.behaviors
                @maximumHitPoints = @type.maximumHitPoints
                @healRate = @type.healRate
                @bodyParts = @type.bodyParts
                @experience = @type.experience
            @uses = { }
            @initLiving()
            if @type
                for name in require( './living' ).statNames()
                    @setBaseStat name, @type[name]
            for behavior in @behaviors ?= [ ]
                require( './behaviors' ).installBehavior behavior, this

Now place the creature into the global instances array and store within the
creature its index in that array as its unique ID.

            for creature, index in Creature::allCreatures
                if creature is null
                    @ID = index
                    Creature::allCreatures[index] = this
                    break
            if not @ID?
                @ID = Creature::allCreatures.length
                Creature::allCreatures.push this

Players have a `getPosition()` member, so creatures should have it as well.

        getPosition : => @location

We therefore create a corresponding "destructor" which should be called to
prepare this creature for garbage collection, such as when the creature
dies.  This function moves the creature out of the global instances array,
thus removing the most important pointer to the object.  Assuming no
one else retains a pointer to this object, it will be garbage collected
hereafter.

Also, if any behaviors were attached to this object, and they made calls to
`setInterval()`, it is necessary for us to clear those intervals when this
object is destroyed.

        destroy : =>
            @moveTo null
            if @ID?
                Creature::allCreatures[@ID] = null
                @ID = null
            require( './behaviors' ).clearIntervalSet @intervalSetIndex
            if @walkInterval? then clearInterval @walkInterval
            setTimeout ( => @emit 'destroyed' ), 0
        wasDestroyed : => not @ID?

This function moves creatures to a new location.  It not only updates this
object's own internal `@location` field, but also notifies the former/next
map blocks, if any, to update their own contents, to stay consistent with
this creature's location.  This is the official way to move a creature while
keeping all data consistent throughout the game.  If the new location is
invalid, then `null` will be used instead.

        moveTo : ( newLocation ) =>
            if @wasDestroyed() then throw 'Creature has been destroyed.'
            oldLocation = @location ? null
            @location = newLocation
            if not require( './blocks' ).moveCreature this, newLocation
                @location = oldLocation

This function is a convenience function that accesses the previous.  It just
takes the current location, if any, and adds the deltas to its x and y
components, then passes the new absolute position to `moveTo()`.

If the optional third parameter is provided, then this step is not taken all
at once, but slowly over the course of the given duration in seconds, with
multiple tiny steps chained together to simulate smooth motion.

        moveBy : ( dx, dy, duration = 0 ) =>
            if @location not instanceof Array then return
            [ plane, x, y ] = @location
            if duration is 0 then return @moveTo [ plane, x + dx, y + dy ]
            whenWalkStarted = new Date
            if @walkInterval? then clearInterval @walkInterval
            @walkInterval = setInterval =>
                if @wasDestroyed()
                    percent = 1
                else
                    now = new Date
                    elapsed = now - whenWalkStarted
                    percent = Math.min 1, elapsed / ( duration * 1000 )
                    @moveTo [ plane, x + percent*dx, y + percent*dy ]
                if percent is 1 then clearInterval @walkInterval
            , 30

Creatures are able to speak.  Simply call this method in one, and it will
make the requisite calls to the animations, sounds, and handlers that go
with a speech event.  This assumes that you have defined an animation for
speaking, as required by the "talk" command in the commands module, and that
it is flexible enough to handle creature speakers.  The maximum text size is
60; longer texts will be truncated.

        say : ( text ) =>
            if text.length > 60 then text = text[...60]
            @attempt 'speak', =>
                require( './animations' ).showAnimation @location, 'speak',
                    { text : text, speaker : @ID }
                require( './sounds' ).playSound 'speech bling', @location
                hearers = require( './blocks' ).whoCanSeePosition @location
                for otherThing in hearers
                    if otherThing isnt player
                        otherThing.emit 'heard', text, player

Creatures are able to carry things.  Use these methods to have the creature
attempt to pick things up or put them down.  Note that the `get` method
does not check to be sure the item is near the creature; this way you can
have creatures take objects you just constructed, but didn't put into the
game map, for instance.  The `get` method does, however, return false if the
item could not be gotten, either due to some blocking behavior or simply the
creature's already holding too much.

        get : ( item ) =>
            if not @canCarry item then return no
            item.attempt 'get', => item.move this
        drop : ( item ) => item.attempt 'drop', => item.move @location

If a player inspects this creature, we show them our inventory.

        gotInspectedBy : ( player ) =>
            player.showUI @inventoryInspected().concat(
                for own name, action of @uses ? { }
                    do ( name, action ) =>
                        type : 'action'
                        value : name[0].toUpperCase() + name[1..]
                        action : => action.apply this, [ player ]
            ).concat [
                type : 'action'
                value : 'Done'
                cancel : yes
                action : -> player.showCommandUI()
            ]

A convenience function for getting a creature's icon.  This is useful in
abilities and behaviors, which do not have access to the modules themselves.

        icon : => module.exports.normalIcon @index

When creature objects need to be transmitted to the client, we do not want
to fill up the network traffic with superfluous data (e.g., behavior
definitions) nor include inventory items that may create circular
structures.  Thus we create the following method that makes a simplified
clone of this object for serialization and sending to the client.

        forClient : =>
            @__forClient ?= { }
            for key in [ 'ID', 'type', 'typeName', 'index', 'location' ]
                @__forClient[key] = this[key]
            @__forClient

Mix handlers into `Creature`s.

    require( './handlers' ).mixIntoClass Creature
    require( './living' ).mixIntoClass Creature

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
            @setDefault 'maximumHitPoints', 100
            @setDefault 'healRate', 1
            @setDefault 'experience', 150
            Living = require './living'
            for name in Living.statNames()
                @setDefault name, Living.statDefault name
            @setDefault 'bodyParts', Living.humanEquipmentTypes()

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
            Living = require './living'
            for statName in Living.statNames()
                @set "#{i}", statName, Living.statDefault statName
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new creature was created with index #{i}.
                You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

Who can edit individual entries in the creatures table is determined by the
authors list, which is the default implementation of `canEdit` in the
`Table` class.

The UI for editing a creature looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            again = => @edit player, entry, callback
            toShow = [
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
                            "<p>A single map cell is an image of size
                            #{N}x#{N}.  Creatures will be shown at their
                            full resolution, so do not upload large images
                            if you do not intend the creatures themselves
                            to be correspondingly large.  Before uploading
                            an icon, consider resizing it on your computer,
                            to save bandwidth and keep the game server
                            responsive.</p>
                            <p><b><u>IMPORTANT:</u></b> Ensure that the
                            creature in the icon you upload is facing to
                            the left, or straight toward the camera.  When
                            creatures move left, their icons are shown
                            normally; when they move right, the icons are
                            flipped.  Orient your creature icon
                            accordingly.</p>",
                            again, ( contents ) =>
                                @setFile entry, 'icon', contents
                ]
            ,
                [
                    type : 'text'
                    value : 'Maximum hit points:'
                ,
                    type : 'text'
                    value : @get entry, 'maximumHitPoints'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : '<h3>Enter new maximum hit points:</h3>
                                <p>For reference, new players start with 100
                                hit points.  A small animal or insect might
                                have 10 hit points, and a bear or elephant
                                might have up to 1000.  Gigantic or magical
                                creatures might have more.</p>'
                        ,
                            type : 'string input'
                            name : 'new max hp'
                            value : @get entry, 'maximumHitPoints'
                        ,
                            type : 'action'
                            value : 'Change'
                            default : yes
                            action : ( event ) =>
                                newval = event['new max hp'].trim()
                                asInt = parseInt newval
                                if isFinite( newval ) \
                                   and not isNaN( asInt ) and asInt > 0
                                    @set entry, 'maximumHitPoints', asInt
                                    again()
                                else
                                    player.showOK 'Maximum hit points must
                                        be a positive whole number.', again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ,
                [
                    type : 'text'
                    value : 'Heal rate:'
                ,
                    type : 'text'
                    value : @get entry, 'healRate'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : '<h3>Enter new heal rate:</h3>
                                <p>This is the number of hit points the
                                creature regains every 2 seconds.  For
                                players, this number is 1.  Do not use a
                                very high value, or the creature
                                will be nearly invincible.</p>'
                        ,
                            type : 'string input'
                            name : 'new heal rate'
                            value : @get entry, 'healRate'
                        ,
                            type : 'action'
                            value : 'Change'
                            default : yes
                            action : ( event ) =>
                                newval = event['new heal rate'].trim()
                                asFloat = parseFloat newval
                                if isFinite( newval ) \
                                   and not isNaN( asFloat ) and asFloat >= 0
                                    @set entry, 'healRate', asFloat
                                    again()
                                else
                                    player.showOK 'Heal rate must be a
                                        non-negative number.', again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ]
            Living = require './living'
            for name in Living.statNames()
                do ( name ) => toShow.push [
                    type : 'text'
                    value : "#{name[0].toUpperCase() + name[1..]}:"
                ,
                    type : 'text'
                    value : @get entry, name
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Enter new #{name}:</h3>"
                        ,
                            type : 'string input'
                            name : "new #{name}"
                            value : @get entry, name
                        ,
                            type : 'action'
                            value : 'Change'
                            default : yes
                            action : ( event ) =>
                                newval = event["new #{name}"].trim()
                                asFloat = parseFloat newval
                                if isFinite( newval ) \
                                   and not isNaN( asFloat )
                                    @set entry, name, asFloat
                                    again()
                                else
                                    player.showOK 'Any stat must be a finite
                                        number, and cannot be NaN.', again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            toShow = toShow.concat [
                [
                    type : 'text'
                    value : "Experience:"
                ,
                    type : 'text'
                    value : @get entry, 'experience'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        sum = @get( entry, 'maximumHitPoints' ) + \
                              @get( entry, 'dodging ability' ) + \
                              @get( entry, 'attack accuracy' ) + \
                              @get( entry, 'minimum damage' ) + \
                              @get( entry, 'maximum damage' )
                        player.showUI
                            type : 'text'
                            value : "<h3>Enter new experience amount:</h3>
                                <p>This is the number of experience points a
                                player earns for killing this creature.  A
                                reasonable value for a creature like this is
                                approximately #{sum} experience points.</p>"
                        ,
                            type : 'string input'
                            name : "new amount"
                            value : @get entry, 'experience'
                        ,
                            type : 'action'
                            value : 'Change'
                            default : yes
                            action : ( event ) =>
                                newval = event["new amount"].trim()
                                asFloat = parseFloat newval
                                if isFinite( newval ) \
                                   and not isNaN( asFloat ) and newval >= 0
                                    @set entry, 'experience', asFloat
                                    again()
                                else
                                    player.showOK 'Experience amount must be
                                        a finite, nonnegative number.',
                                        again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ,
                [
                    type : 'text'
                    value : '<b>Body parts:</b>'
                ,
                    type : 'text'
                    value : @get( entry, 'bodyParts' ).join ', '
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        save = ( newList ) =>
                            @set entry, 'bodyParts', newList
                            again()
                        require( './ui' ).editListUI player,
                            @get( entry, 'bodyParts' ),
                            "Editing list of body parts for creature
                                \"#{@get entry, 'name'}\" (that is, body
                                parts that can wear equipment)",
                            ( -> yes ), save, again
                ]
            ,
                type : 'action'
                value : 'Edit behaviors'
                action : =>
                    creature = new Creature entry, null
                    require( './behaviors' ).editAttachments player,
                        creature, =>
                            @set entry, 'behaviors', creature.behaviors
                            creature.destroy()
                            again()
            ,
                type : 'action'
                value : 'Spawn one at my location'
                action : =>
                    creature = new Creature entry
                    creature.moveTo player.getPosition()
                    player.showOK "An instance of creature #{entry},
                        \"#{@get entry, 'name'},\" has been spawned at your
                        location.", again
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback
            ]
            player.showUI toShow

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
