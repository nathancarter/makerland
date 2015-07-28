
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

## Global data

Our first big global data structure is a list of stats that each living will
have, together with its default values.

    statsDefaultValues =

Minimum and maximum damage refer to how much damage this creature does when
striking other creatures.  The actual damage on a given hit is chosen
uniformly from within this range.

        'minimum damage' : 5
        'maximum damage' : 15

Attack accuracy is the ability to connect successfully when you attempt to
hit an enemy.  Dodging ability is its counterpart, the ability to avoid
being hit when an enemy attempts to hit you.  These numbers are largely
irrelevant in the absolute; what matters is how the values of an attacker
and defender compare.  Making them equal by default means that livings with
default stats have a 50% chance of hitting one another on each swing.

        'attack accuracy' : 10
        'dodging ability' : 10

This is the rate at which the player walks around the game world, in units
of blocks per second.

        'movement rate' : 2

These stats can be queried using the following API.

    module.exports.statNames = -> Object.keys statsDefaultValues
    module.exports.statDefault = ( key ) -> statsDefaultValues[key]

The second big global data structure is a list of equipment types that a
normal human-shaped creature can use.  These are a list of body parts that
can accept equipment.  Non-human-shaped creatures will need to choose
different parts; it is not necessary that they appear on this global list.

    humanEquipmentTypes = [
        'head'
        'neck'
        'body'
        'arms'
        'legs'
        'feet'
        'hands'
        'weapon'
    ]

These types can be queried using the following API.

    module.exports.humanEquipmentTypes = -> humanEquipmentTypes[..]

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
        @equipment = { }
        if this instanceof require( './creatures' ).Creature
            setTimeout => # randomly offset heartbeat from others'
                @__heartBeatInterval = setInterval =>
                    @heartBeat()
                , 2000
            , Math.random()*2000
        scope.stats ?= { }
        scope.stats[key] ?= value for own key, value of statsDefaultValues

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
        if delta > @healRate ? 1
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

When a living dies, handle it as follows.  First, emit events and play
sounds and animations.

    module.exports.methods.death = ( killer ) ->
        killer?.emit 'killed', this
        @emit 'died', killer
        require( './animations' ).showAnimation @getPosition(),
            'death', position : @getPosition()
        require( './sounds' ).playSound 'death knell', @getPosition()

If a player killed a creature, grant experience points.

        if ( killer instanceof require( './player' ).Player ) and \
           ( this instanceof require( './creatures' ).Creature )
            killer.saveData.experience ?= 0
            killer.saveData.experience += @experience ? 0

This living, at death, should drop all its possessions.

        for item in ( @inventory ? [ ] ).slice()
            destination = @getPosition()
            destination[1] += Math.random()
            destination[2] += Math.random()
            item.move destination

Things that die stop attacking, get marked as dead, stop their heartbeat,
and either disconnect (if players) or are destroyed (if creatures).

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
        items = [ ]
        equipment = [ ]
        for item in @inventory
            row = [
                type : 'text'
                value : require( './movableitems' ).smallIcon item.index
            ,
                type : 'text'
                value : item.typeName + if item.isEquipped() then \
                    " (equipped, #{item.equipmentType})" else ''
            ]
            ( if item.isEquipped() then equipment else items ).push row
        items = equipment.concat items
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

Being attacked by an enemy adds them to the bottom of your enemies list.  If
they were already on that list, they are not moved.

    module.exports.methods.attackedBy = ( enemy ) ->
        if enemy not in @enemies then @enemies.push enemy

The following function filters the enemies list by those that are with a
given radius of the player.

    module.exports.methods.enemiesWithin = ( radius ) ->
        whereIAm = @getPosition()
        if not whereIAm? then return [ ]
        closeEnough = ( enemy ) ->
            whereItIs = enemy.getPosition()
            if not whereItIs? or whereIAm[0] isnt whereItIs[0]
                return no
            dx = whereIAm[1] - whereItIs[1]
            dy = whereIAm[2] - whereItIs[2]
            Math.sqrt( dx*dx + dy*dy ) <= radius
        ( enemy for enemy in @enemies when closeEnough enemy )

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
        reachableEnemies = @enemiesWithin 1
        if reachableEnemies.length is 0 then return
        target = reachableEnemies[0]

We have found the highest-priority enemy on our enemies list that's close
enough to strike.  At this point, it doesn't matter whether our attack
succeeds, the enemy should be notified that we have attacked it.

        target.attackedBy this

Now we test whether we randomly succeed in our attempt to strike it.  If we
missed, play a "miss" sound and stop.

        random = require './random'
        if not random.statCompetition( this,   'attack accuracy',
                                       target, 'dodging ability' )
            require( './sounds' ).playSound 'miss', @getPosition()
            this.emit 'missed target', target
            target.emit 'dodged attack', this
            return

Our hit connected, so execute a normal combat strike against the enemy.

        @hitEnemy target

The previous function uses the following method to do an ordinary combat hit
against an enemy.  We factor it out here so that it can be used at other
times as well.

    module.exports.methods.hitEnemy = ( target ) ->

First check to see if there are any event handlers that block our attempt to
actually do damage.

        random = require './random'
        @attempt 'hit', => target.attempt 'got hit', =>

If not, then the following code will be run.  It computes and delivers the
damage, with a corresponding animation that shows a small projectile moving
from attacker to target.  Animation and sound for the actual damage will
be triggered by the change in health.

            min = @getStat 'minimum damage'
            max = @getStat 'maximum damage'
            damage = random.uniformClosed min, max
            require( './animations' ).showAnimation @getPosition(), 'hit',
                agent : this.name ? this.ID
                target : target.name ? target.ID
                strength : damage/50 + 0.5
            target.changeHealth -damage, this

## Stats for Livings

A living's base value for a statistic is stored in its stats mapping.  We
can read and write it as follows.

    module.exports.methods.getBaseStat = ( key ) ->
        ( @saveData ? this )?.stats?[key]
    module.exports.methods.setBaseStat = ( key, value ) ->
        scope = @saveData ? this
        scope.stats[key] = value

Some base stats cannot be incremented at certain times, so we provide a
function that checks to see if we can increase it, and one that does
increment it if we can.  The check function returns undefined if we *can*
increment it, and a string explaining why not if we cannot.

    module.exports.methods.checkIncrementBaseStat = ( key ) ->
        if key is 'minimum damage' and \
           @getBaseStat( key ) >= @getBaseStat 'maximum damage'
            'You must increase your maximum damage first.'
    module.exports.methods.incrementBaseStat = ( key ) ->
        if not @checkIncrementBaseStat key
            @setBaseStat key, 1 + @getBaseStat key

Stat bonuses are stored in a separate object, so that they can be easily
reported as bonuses, and so that they do not get accidentally permanently
added to the base stats.

    module.exports.methods.getStatBonus = ( key ) -> @statBonuses?[key] ? 0
    module.exports.methods.setStatBonus = ( key, value ) ->
        @statBonuses ?= { }
        @statBonuses[key] = value
    module.exports.methods.addStatBonus = ( key, value, duration = 0 ) ->
        @setStatBonus key, value + @getStatBonus key
        if duration
            setTimeout ( => @addStatBonus key, -value ), duration

The actual value of a stat for a living is the base plus the bonus.

    module.exports.methods.getStat = ( key ) ->
        @getBaseStat( key ) + @getStatBonus( key )

## Equipment for Livings

This function causes a living to equip an item.  Several checks need to be
made first.  This function either returns a string explaining why the item
couldn't be equipped, or undefined if the equipping succeeded.

    module.exports.methods.equip = ( item ) ->

The living must be holding the item and be able to equip it (i.e., have the
right body part).

        if item.location isnt this
            return 'You are not carrying that.'
        myBodyParts = @bodyParts ? module.exports.humanEquipmentTypes()
        if item.equipmentType not in myBodyParts
            return 'You cannot equip things of that type.'

If something else is already equipped, unequip that first.

        if @equipment[item.equipmentType]
            @unequip @equipment[item.equipmentType]

Now equip what I was asked to equip.

        @equipment[item.equipmentType] = item
        item.emit 'equipped by', this
        this.emit 'equipped item', item
        @updateEquipmentStatus?()
        return

This function is the reverse, unequipping something that you have equipped.
Again, it checks to be sure this makes sense, and returns an error message
on failure, or none on success.

    module.exports.methods.unequip = ( item ) ->
        for own type, equippedItem of @equipment
            if equippedItem is item
                delete @equipment[type]
                item.emit 'unequipped by', this
                this.emit 'unequipped item', item
                @updateEquipmentStatus?()
                return
        'But you are not using that item now.'
