
# Livings Mixin

A mixin is a way to add functionality to an object without using prototypes
(or classes, in CoffeeScript parlance).  Thus multiple mixins can be added
to the same object; usually the mixins are added to a prototype/class, but
that is optional, and they themselves are not a prototype/class.

This module defines several functions that support living things in the
game, such as hit points and healing.  Each is explained below.

## The Mixing Operation

Call one of the following functions to mix the "living" functionality into
any object, class, or prototype.

    module.exports.mixIntoObject = ( object ) ->
        object[name] = method for own name, method of module.exports.methods
        object
    module.exports.mixIntoClass = ( klass ) ->
        module.exports.mixIntoObject klass.prototype
    module.exports.mixIntoConstructor = module.exports.mixIntoClass

## Livings Functions

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

    module.exports.methods.initHealth = ->
        scope = @saveData ? this
        scope.maximumHitPoints ?= 100
        scope.hitPoints ?= scope.maximumHitPoints

The second function adds a player's health data to the player's status
object before it's transmitted to the client for displaying.

    module.exports.methods.addHealthToStatus = ( status ) ->
        scope = @saveData ? this
        status.hitPoints = scope.hitPoints
        status.maximumHitPoints = scope.maximumHitPoints
        if scope.hitPoints < 0 then status.dead = yes

All changes to a living's hit points should go through this function.  It
takes care of notifying clients about hit point changes, which are very
important.  The method is called `changeHealth` because it can be used to
increase or decrease; simply pass positive (or negative) changes,
respectively.  Show a healing animation if the change was a large enough
increase, or a harming animation if it was a large enough decrease.  If the
living dies, trigger the death routine.

    module.exports.methods.changeHealth = ( delta ) ->
        if typeof delta isnt 'number' then return
        if not isFinite( delta ) or isNaN delta then return
        scope = @saveData ? this
        scope.hitPoints += delta
        if scope.hitPoints > scope.maximumHitPoints
            scope.hitPoints = scope.maximumHitPoints
        if delta / scope.maximumHitPoints > 0.03
            require( './animations' ).showAnimation @getPosition(),
                'sparkle', { target : this.name, color : '#ffff66' }
            require( './sounds' ).playSound 'gentle bell', @getPosition()
        if delta / scope.maximumHitPoints < -0.03
            require( './animations' ).showAnimation @getPosition(),
                'sparkle', { target : this.name, color : '#cc0000' }
            require( './sounds' ).playSound 'bone crack', @getPosition()
        if scope.hitPoints < 0 then @death() else @updateStatus?()

Livings have a heart beat, which heals them slowly.

    module.exports.methods.heartBeat = ->
        @changeHealth 1

When a living dies, handle it as follows.  First, move all their possessions
out onto the ground nearby.  Then, if the object is a player instead of a
creature, do three things: update their status, mark their time of death,
and disconnect the socket.

    module.exports.methods.death = ->
        for item in ( @inventory ? [ ] ).slice()
            destination = @getPosition()
            destination[1] += Math.random()
            destination[2] += Math.random()
            item.move destination
        @updateStatus?()
        @saveData?.timeOfDeath = new Date
        @socket?.disconnect()

This function is called when the game re-awakens a player from death.  It
gives them a small amount of hit points from which they will be able to
slowly heal.

    module.exports.methods.awakenFromDeath = ->
        scope = @saveData ? this
        delete scope.timeOfDeath
        scope.hitPoints = Math.min scope.maximumHitPoints, 50
