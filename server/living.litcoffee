
# Livings Mixin

A mixin is a way to add functionality to an object without using prototypes
(or classes, in CoffeeScript parlance).  Thus multiple mixins can be added
to the same object; usually the mixins are added to a prototype/class, but
that is optional, and they themselves are not a prototype/class.

This module defines several functions that support living things in the
game, such as hit points, healing, and inventory.  Each is explained below.

## The Mixing Operation

Call one of the following functions to mix the "living" functionality into
any object, class, or prototype.

    module.exports.mixIntoObject = ( object ) ->
        object[name] = method for own name, method of module.exports.methods
        object
    module.exports.mixIntoClass = ( klass ) ->
        module.exports.mixIntoObject klass.prototype
    module.exports.mixIntoConstructor = module.exports.mixIntoClass

## Livings Initialization

    module.exports.methods = { }

Each of the functions below uses `@`-style identifier access as a shorthand
for the JavaScript `this` keyword, because these methods are only intended
to be run after they've been mixed into a particular object.

All functions in this module first test whether they should be using fields
in `saveData` or the object itself, so that these methods are flexible
enough to work on both players (which have a `saveData` member) and
creatures (which do not).

This first function is an initializer.  Any class into which this mixing is
mixed must call this initializer.  Player objects should call it after the
player's `saveData` is loaded; creatures should call it after construction.

    module.exports.methods.initLiving = ->
        scope = @saveData ? this
        scope.maximumHitPoints ?= 100
        scope.hitPoints ?= scope.maximumHitPoints
        @inventory = [ ]
        @enemies = [ ]
        if this instanceof require( './creatures' ).Creature
            @__heartBeatInterval = setInterval =>
                @heartBeat()
            , 2000

## Health for Livings

Getters for health and maximum health.

    module.exports.methods.getHealth = -> ( @saveData ? this ).hitPoints
    module.exports.methods.getMaxHealth = ->
        ( @saveData ? this ).maximumHitPoints

This function adds a player's health data to the player's status object
before it's transmitted to the client for displaying.

    module.exports.methods.addHealthToStatus = ( status ) ->
        status.hitPoints = @getHealth()
        status.maximumHitPoints = @getMaxHealth()
        if status.hitPoints < 0 then status.dead = yes

All changes to a living's hit points should go through this function.  It
takes care of notifying clients about hit point changes, which are very
important.  The method is called `changeHealth` because it can be used to
increase or decrease; simply pass positive (or negative) changes,
respectively.  Show a healing animation if the change was a large enough
increase, or a harming animation if it was a large enough decrease.  If the
living dies, trigger the death routine.

    module.exports.methods.changeHealth = ( delta, agent ) ->
        if typeof delta isnt 'number' then return
        if not isFinite( delta ) or isNaN delta then return
        scope = @saveData ? this
        scope.hitPoints += delta
        if scope.hitPoints > scope.maximumHitPoints
            scope.hitPoints = scope.maximumHitPoints
        if delta / scope.maximumHitPoints > 0.03
            require( './animations' ).showAnimation @getPosition(),
                'sparkle',
                target : this.name ? this.ID
                color : '#ffff66'
            require( './sounds' ).playSound 'gentle bell', @getPosition()
        if delta / scope.maximumHitPoints < 0
            require( './animations' ).showAnimation @getPosition(),
                'sparkle',
                target : this.name ? this.ID
                color : '#cc0000'
            require( './sounds' ).playSound 'bone crack', @getPosition()
        if scope.hitPoints < 0 then @death agent else @updateStatus?()

Livings have a heart beat, which heals them slowly, as long as they remain
alive.  It also causes the living to perform an attack on its enemies, a
routine defined later in this module.

    module.exports.methods.heartBeat = ->
        @changeHealth @healRate ? 1
        @fightEnemies()

When a living dies, handle it as follows.  First, move all their possessions
out onto the ground nearby.  Then, if the object is a player instead of a
creature, do three things: update their status, mark their time of death,
and disconnect the socket.

    module.exports.methods.death = ( killer ) ->
        killer.emit 'killed', this
        @emit 'died', killer
        for item in ( @inventory ? [ ] ).slice()
            destination = @getPosition()
            destination[1] += Math.random()
            destination[2] += Math.random()
            item.move destination
        @enemies = [ ]
        @updateStatus?()
        @saveData?.timeOfDeath = new Date
        @socket?.disconnect()
        if @__heartBeatInterval?
            clearInterval @__heartBeatInterval
            delete @__heartBeatInterval
        @destroy?()

This function is called when the game re-awakens a player from death.  It
gives them a small amount of hit points from which they will be able to
slowly heal.

    module.exports.methods.awakenFromDeath = ->
        scope = @saveData ? this
        delete scope.timeOfDeath
        scope.hitPoints = Math.min scope.maximumHitPoints, 50

## Inventory for Livings

The following functions put items into the player's/creature's inventory, or
take them out.  Neither function manipulates the inner data of the item
itself.  Thus you should not call these functions yourself, because they
will mess up data consistency.  Rather, you should call the item's `move()`
function, which will call these functions in turn.  Be sure to first check
the `canCarry()` function, defined below.

    module.exports.methods.addItemToInventory = ( item ) ->
        if item not in @inventory then @inventory.push item
    module.exports.methods.removeItemFromInventory = ( item ) ->
        if ( index = @inventory.indexOf item ) > -1
            @inventory.splice index, 1

Can the player/creature add another item to their inventory?  This function
checks the new total that would amount to against their maximum carrying
capacity.

    module.exports.methods.canCarry = ( item ) ->
        capacity = @saveData?.capacity ? @capacity ? 10
        carrying = 0
        carrying += heldItem.space for heldItem in @inventory
        carrying + item.space <= capacity

Call this function to find an item (or all items) in the player's/creature's
inventory that match the given data.
 * If the data is a number, it will be matched against the items' indices in
   the movable items table.  This includes the case where data is a string
   containing just a single positive integer.
 * If it is a string, it will be matched against the items' names.
 * If it is a regexp, it will be tested against the items' names.

    module.exports.methods.searchInventory = ( data, multiple = false ) ->
        check = ( item ) ->
            if typeof data is 'number' then return item.index is data
            if typeof data is 'string' and /^[0-9]+$/.test data
                return "#{item.index}" is data
            if data instanceof RegExp then return data.test item.typeName
            "#{data}".toLowerCase() is item.typeName.toLowerCase()
        results = [ ]
        for item in @inventory
            if check item
                if not multiple then return item else results.push item
        if multiple then results else null

The following function is useful when creating `gotInspectedBy()`
implementations, which must show the inventory.  This creates a portion of a
command pane UI, listing the items in the player's/creature's inventory.
Any additional controls can be added to the end of this array before it is
shown with `player.showUI()`.

    module.exports.methods.inventoryInspected = ->
        items = ( [
            type : 'text'
            value : require( './movableitems' ).smallIcon item.index
        ,
            type : 'text'
            value : item.typeName
        ] for item in @inventory )
        if items.length is 0 then items = [
            type : 'text'
            value : '(no items)'
        ]
        capname = if @typeName
            @typeName[0].toUpperCase() + @typeName[1..]
        else
            'Player ' + @name[0].toUpperCase() + @name[1..]
        items.unshift
            type : 'text'
            value : "<h3>#{capname}'s inventory:</h3>"
        items

## Combat for Livings

Attacking an enemy adds them to the top of your enemies list.  If they were
already on that list, they are moved to the top instead of added again.

    module.exports.methods.attack = ( enemy ) ->
        if ( already = @enemies.indexOf enemy ) > -1
            @enemies.splice already, 1
        @enemies.unshift enemy

Begin attacked by an enemy adds them to the bottom of your enemies list.  If
they were already on that list, they are not moved.

    module.exports.methods.attackedBy = ( enemy ) ->
        if enemy not in @enemies then @enemies.push enemy

The following routine is called every heartbeat in this living.  It
implements a single step of combat.  Details below.

    module.exports.methods.fightEnemies = ->

First, we clean out our list of enemies so that it does not include anyone
who has died or logged out.

        stillAround = ( enemy ) ->
            not enemy.saveData?.timeOfDeath \
            and not enemy.wasDestroyed?() and enemy.getPosition?()?
        @enemies = ( e for e in @enemies when stillAround e )

Next, we attempt to fight the highest-priority enemy within reach.

        whereIAm = @getPosition()
        for enemy in @enemies
            whereItIs = enemy.getPosition()
            if whereIAm[0] isnt whereItIs[0] then continue
            dx = whereIAm[1] - whereItIs[1]
            dy = whereIAm[2] - whereItIs[2]
            if Math.sqrt( dx*dx + dy*dy ) > 1 then continue

We have found the highest-priority enemy on our enemies list that's close
enough to strike.  The following code attempts to strike it.

            @attempt 'hit', => enemy.attempt 'got hit', =>
                require( './animations' ).showAnimation @getPosition(),
                    'hit',
                    agent : this.name ? this.ID
                    target : enemy.name ? enemy.ID
                enemy.changeHealth -10, this
                enemy.attackedBy this

We can only attempt to strike one enemy at a time, so we now stop searching
for enemies to strike.

            break
