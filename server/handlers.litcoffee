
# Handlers Mixin

A mixin is a way to add functionality to an object without using prototypes
(or classes, in CoffeeScript parlance).  Thus multiple mixins can be added
to the same object; usually the mixins are added to a prototype/class, but
that is optional, and they themselves are not a prototype/class.

This module defines several functions that implement "handlers," an
event-emitting and event-handling system.  These are explained below.

## The Mixing Operation

Call one of the following functions to mix the handler functionality into
any object, class, or prototype.

    module.exports.mixIntoObject = ( object ) ->
        object[name] = method for own name, method of module.exports.methods
        object
    module.exports.mixIntoClass = ( klass ) ->
        module.exports.mixIntoObject klass.prototype
    module.exports.mixIntoConstructor = module.exports.mixIntoClass

## Handlers Functions

    module.exports.methods = { }

Each of the functions below uses `@`-style identifier access as a shorthand
for the JavaScript `this` keyword, because these methods are only intended
to be run after they've been mixed into a particular object.

This first function installs a new handler for an event into an object and
returns the handler's unique ID.

    module.exports.methods.on = ( eventName, handler ) ->
        @handlers ?= __ids : [ ]
        handler.__id = 0
        while handler.__id in @handlers.__ids then handler.__id++
        ( @handlers[eventName] ?= [ ] ).push handler
        @handlers.__ids.push handler.__id
        handler.__id

This second function uninstalls a handler, if given the unique ID returned
at the handler's installation.

    module.exports.methods.remove = ( id ) ->
        @handlers.__ids = ( i for i in @handlers.__ids when i isnt id )
        for own eventName, handlerList of @handlers
            @handlers[eventName] = ( handler for handler in \
                @handlers[eventName] when handler.__id isnt id )

The emit function runs all handlers installed for an event, up until one of
them returns a value, thus stopping further execution.  The value of the
last-run handler is returned (or undefined if none returns a value).

    module.exports.methods.emit = ( eventName, args... ) ->
        for handler in @handlers?[eventName] ? [ ]
            if result = handler.apply this, args then return result
        undefined

The following function can be used when an event is about to happen, but is
the type that may be blocked.  The `run` parameter should be a function that
executes a specific action, and `fail` should be a function to run if `run`
fails (in the following sense).

Before calling `run`, we emit the "before [event name]" event.  If its value
is undefined or is false, then the event handlers did *not* attempt to block
the event.  In that case, we execute `run` on the given arguments list.
Assuming that it executes with no errors, we then emit the "after [event
name]" event.

However, if the "before [event name]" handler returned a true value, then
the handlers intend to block the event, so we should execute the `fail`
function instead, passing the same arguments as we would have to `run`.  The
one exception is that we prepend that list of arguments with the return
value from the "before" handlers, in case it was a useful error message,
such as a reason for why the attempt failed, which we may want to show to
the player.  We do not emit the "after [event name]" event in this case.

This is a convenience function that can be called when any code is about to
be executed, but we want to provide event handlers the ability to react to
it and possibly even block it.

    module.exports.methods.attempt = ( eventName, run, fail, args... ) ->
        try
            if failReason = @emit "before #{eventName}", args...
                fail failReason, args...
            else
                run args...
                @emit "after #{eventName}", args...
