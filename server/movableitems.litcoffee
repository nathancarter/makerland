
# Movable Items

Technically, this table is a list of the *types* of movable items that can
be carried around by players and dropped on the map, and thus for
consistency should possibly be named `movableitemtypes`, but that's just too
long a module name.

Movable items can be held by players or creatures, dropped on the map, or
put into containers.  When sitting on the map, they are not necessarily at
integer coordinates, but sit just like landscape items.

## Movable Items Class

We now create a class for embodying those movable items which exist in
players' inventories, or in blocks of the map that are currently loaded.

    class MovableItem

All instances of the class will be kept in a global array, whose indices
give them a unique ID.

        allItems : [ ]

We can therefore look up an instance based on its ID.

        itemForID : ( id ) -> MovableItem::allItems[id]

At construction time, we must be told which type of movable item we are, and
we must also know our location, which must either be a player or creature
carrying us, or a position on the map as a plane,x,y triple.

        constructor : ( @index, @location ) ->
            if @type = module.exports.getWithDefaults @index
                @typeName = @type.name
                @space = @type.space
                @behaviors = @type.behaviors
                @equipmentType = @type.equipmentType
            @uses = { }
            for behavior in @behaviors ?= [ ]
                require( './behaviors' ).installBehavior behavior, this

Now place the item into the global instances array and store within the item
its index in that array as its unique ID.

            for item, index in MovableItem::allItems
                if item is null
                    @ID = index
                    MovableItem::allItems[index] = this
            if not @ID?
                @ID = MovableItem::allItems.length
                MovableItem::allItems.push this

We therefore create a corresponding "destructor" which should be called to
prepare this object for garbage collection.  This function moves the item
out of its current environment and out of the global instances array, thus
removing the two most important pointers to the object.  Assuming no one
else retains a pointer to this object, it will be garbage collected
hereafter.

Also, if any behaviors were attached to this object, and they made calls to
`setInterval()`, it is necessary for us to clear those intervals when this
object is destroyed.

        destroy : =>
            @move null
            if @ID?
                MovableItem::allItems[@ID] = null
                @ID = null
            require( './behaviors' ).clearIntervalSet @intervalSetIndex
            setTimeout ( => @emit 'destroyed' ), 0
        wasDestroyed : => not @ID?

This function moves items to a new location.  It not only updates this
item's own internal `@location` field, but also notifies the former/next
locations, if any, to update their own contents, to stay consistent with
this item's location.  This is the official way to move an item while
keeping all data consistent throughout the game.  If the new location is
invalid, then `null` will be used instead.

        move : ( newLocation ) =>
            if @location and 'removeItemFromInventory' of @location
                @location.unequip? this
                @location.removeItemFromInventory this
            else if @location instanceof Array
                require( './blocks' ).removeMovableItemFromMap this
            @location = newLocation
            if @location and 'addItemToInventory' of @location
                @location.addItemToInventory this
            else if @location instanceof Array
                require( './blocks' ).addMovableItemToMap this, @location
            else
                @location = null

For movable items, serialization is straightforward because movable items
have no individual properties.  They are determined completely by their
index in the movable items table.  The serialization is to and from objects
that are JSONable.

        serialize : => index : @index
        @deserialize : ( dataObj ) ->
            if dataObj.index? then new MovableItem dataObj.index else null

If this item gets inspected by a player, just print its basic information.

        gotInspectedBy : ( player ) =>
            player.showUI
                type : 'text'
                value : "<h3>Inspecting #{@typeName}:</h3>"
            ,
                type : 'text'
                value : module.exports.normalIcon @index
            ,
                type : 'text'
                value : "<p>Size: #{@space}</p>"
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : -> player.showCommandUI()

We can detect whether we are equipped by looking up our equipment type in
our holder's equipment mapping (if we have a holder).

        isEquipped : =>
            if not @location? or @location instanceof Array
                return no
            @location.equipment?[@equipmentType] is this

A convenience function for getting a movable item's icon.  This is useful in
abilities and behaviors, which do not have access to the modules themselves.

        icon : => module.exports.normalIcon @index

Mix handlers into `MovableItem`s.

    require( './handlers' ).mixIntoClass MovableItem

## Movable Items Table

Most of this module is a database table, so we require the table module,
plus some others.

    { Table } = require './table'
    { Player } = require './player'
    fs = require 'fs'
    path = require 'path'

It subclasses the main Table class and adding movable-item-specific
functionality.

    class MovableItemsTable extends Table

## Table Constructor

        constructor : () ->

First, give the table its name and set default values for keys.

            super 'movableitems', 'Movable Items'
            @setDefault 'space', 1
            @setDefault 'equipmentType', ''

## Maker Database Browsing

Implement custom show method.

        show : ( entry ) =>
            "<p>#{entry}. #{@normalIcon entry} #{@get( entry ).name}</p>"

Ensure entries are returned sorted in numerical order.

        entries : => super().sort ( a, b ) -> parseInt( a ) - parseInt( b )

Whenever an entry in the table changes, notify all players to update their
client-side movable item caches.

        set : ( entryName, others... ) =>
            super entryName, others...
            for p in Player::allPlayers
                p.socket.emit 'movable item changed', entryName

## Maker Permissions

Any maker can add new entries to the table.  The UI for doing so looks like
the following.

        canAdd : -> yes
        add : ( player, callback = -> player.showCommandUI() ) =>
            entries = @entries()
            i = 1
            while "#{i}" in entries
                i++
            @set "#{i}", name : 'new movable item'
            @setAuthors "#{i}", [ player.name ]
            player.showOK "The new movable item was created with index
                #{i}.  You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

Who can edit individual entries in the movable items table is determined by
the authors list, which is the default implementation of `canEdit` in the
`Table` class.

The UI for editing a movable item looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h3>Editing movable item #{entry}:</h3>"
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
                            value : "<h3>Changing name of movable item
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new movable item name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new movable item name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of movable item
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
                    value : 'Icon:'
                ,
                    type : 'text'
                    value : @normalIcon entry
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        N = require( './settings' ).cellSizeInPixels
                        player.getFileUpload "#{@get entry, 'name'} icon",
                            "A single map cell is an image of size
                            #{N}x#{N}.  Since movable items must be
                            carryable by a player, they should be smaller
                            than that.  Before uploading an icon, consider
                            resizing it on your computer to be #{N}x#{N}
                            or smaller, to save bandwidth and keep the game
                            server responsive.",
                            again, ( contents ) =>
                                @setFile entry, 'icon', contents
                ]
            ,
                [
                    type : 'text'
                    value : 'Space it takes up:'
                ,
                    type : 'text'
                    value : @get entry, 'space'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing space taken up by movable
                                item #{entry} (in a container or in a
                                player's inventory):</h3>"
                        ,
                            type : 'string input'
                            name : 'new amount'
                        ,
                            type : 'action'
                            value : 'Change space'
                            default : yes
                            action : ( event ) =>
                                newamount = event['new amount']
                                asfloat = parseFloat newamount
                                if isNaN( asfloat ) or \
                                   not isFinite( asfloat ) \
                                   or asfloat < 0
                                    return player.showOK 'New amount must
                                        be a non-negative number.', again
                                @set entry, 'space', asfloat
                                player.showOK "Size of movable item
                                    #{entry} changed to #{asfloat}.", again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ,
                [
                    type : 'text'
                    value : 'Type of equipment:'
                ,
                    type : 'text'
                    value : @get entry, 'equipmentType'
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        humanTypes = require( './living' ) \
                            .humanEquipmentTypes()
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing equipment type for
                                #{@get entry, 'name'}:</h3>
                                <p>If this can be worn, for example on the
                                head as a helmet or hat, use \"head\" as the
                                type of equipment.  The full set of human
                                body parts that can accept equipment is
                                #{humanTypes.join ', '}.  But you can use
                                any value (e.g., tentacles for an octopus).
                                If this is not a piece of wearable
                                equipment, make its equipment type
                                blank.</p>"
                        ,
                            type : 'string input'
                            name : 'equipment type'
                        ,
                            type : 'action'
                            value : 'Change equipment type'
                            default : yes
                            action : ( event ) =>
                                newtype = event['equipment type']
                                @set entry, 'equipmentType', newtype
                                player.showOK "Equipment type for movable
                                    item #{entry} changed to #{newtype}.",
                                    again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ,
                type : 'action'
                value : 'Edit behaviors'
                action : =>
                    item = new MovableItem entry, null
                    require( './behaviors' ).editAttachments player, item,
                        =>
                            @set entry, 'behaviors', item.behaviors
                            item.destroy()
                            again()
            ,
                type : 'action'
                value : 'Add one to my inventory'
                action : =>
                    item = new MovableItem entry
                    item.move player
                    item.emit 'after get', player
                    player.showOK "An instance of movable item #{entry},
                        \"#{@get entry, 'name'},\" has been added to your
                        inventory.", again
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback

A maker can remove a movable item type if and only if that maker can edit
it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the movable item #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 instances of this movable item in the game map or in any
                 players' inventories, they will (sooner or later)
                 disappear and/or stop functioning!", action, callback

## Exporting

The module then exports a single instance of the `MovableItemsTable` class,
and the `MovableItem` class as an attribute thereof.

    module.exports = new MovableItemsTable
    module.exports.MovableItem = MovableItem
