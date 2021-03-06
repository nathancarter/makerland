
# Behaviors Table

This module implements a game database table for storing behaviors, which
are blocks of code that can be run to install functionality in a variety of
types of objects, such as landscape items.

    { Table } = require './table'

Behaviors come in a variety of types.  The following list will grow as new
types of behaviors are added to the game.  Each type name maps to the class
for objects of that type, so we can test `instanceof` later.

    behaviorTypes =
        'landscape item' : require( './landscapeitems' ).LandscapeItem
        'movable item' : require( './movableitems' ).MovableItem
        'creature' : require( './creatures' ).Creature

It does so by subclassing the main Table class and adding behavior-specific
functionality.

    class BehaviorsTable extends Table

## Constructor

The constructor just sets the name of the table, then some defaults.

        constructor : () ->
            super 'behaviors'
            @setDefault 'description', ''
            @setDefault 'code', ''

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
                        for own type of behaviorTypes
                            controls.push
                                type : 'checkbox'
                                name : type
                                checked : type in ( data.targets or [ ] )
                        controls = controls.concat [
                            type : 'action'
                            value : 'Save changes'
                            default : yes
                            action : ( event ) =>
                                @set entry, 'targets',
                                    ( type for own type of behaviorTypes \
                                      when event[type] )
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
                value : 'Edit parameters'
                action : =>
                    require( './ui' ).editKeyValuePairs player,
                        'parameter name', 'parameter description',
                        "Parameters for #{data.name}",
                        'Create parameters for the behavior by adding the
                        parameter name on the left, then describing it in
                        words a user can understand on the right.  You can
                        provide a default value for a parameter named, for
                        example, "duration", by creating another entry
                        called "default duration" and settings its value to
                        your desired default.',
                        data.parameters or [ ],
                        ( result ) =>
                            if result then @set entry, 'parameters', result
                            again()
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
                        type : 'text'
                        value : '<p>Not sure how to write this code?
                            <a href="docs/coding.html#behaviors"
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

A maker can remove a behavior if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = => player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the behavior #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 objects using this behavior in the game, they will no
                 longer have this functionality!", action, callback

## Attaching Behaviors to Objects

The following UI can be used to let a maker choose which behaviors they want
to attach to a given object.  The object must be an instance of a type of
thing that can have behaviors attached, such as a `LandscapeItem`.

The player can make edits to the object, which will be written to the
object's `behaviors` attribute, and `save()` called in the object.  The
callback will be called when the player clicks Done.

        editAttachments : ( player, object, callback ) =>
            again = => @editAttachments player, object, callback
            object.behaviors ?= [ ]
            beTable = require './behaviors'
            for own name, type of behaviorTypes
                if object instanceof type then typeName = name
            if not typeName?
                return player.showOK 'Somehow you are editing the behaviors
                    of an invalid object.  You cannot do that.  Sorry!',
                    -> callback no
            controls = [
                type : 'text'
                value : "<h3>Editing behaviors of a #{typeName}:</h3>"
            ,
                type : 'text'
                value : '<h4>Behaviors already attached to the object:</h4>'
                class : 'line-above'
            ]
            for behavior, index in object.behaviors
                do ( index, behavior ) =>
                    # must use variables not yet used, to preserve "do"
                    btype = beTable.get behavior['behavior type']
                    params = [ ]
                    for own key, value of behavior
                        if key isnt 'behavior type'
                            params.push "#{key}: #{value ?
                                type.parameters["default #{key}"] ?
                                '(unspecified)'}"
                    controls.push [
                        type : 'text'
                        value : "<b>Name:</b><br>#{btype.name}"
                    ,
                        type : 'text'
                        value : "<b>Parameters:</b><br>#{params.join ', '}"
                    ]
                    pair = [ ]
                    if Object.keys( btype.parameters ? { } ).length > 0
                        pair.push
                            type : 'action'
                            value : 'Edit'
                            action : =>
                                controls = [
                                    type : 'text'
                                    value : "<h3>Editing #{name}:</h3>"
                                ]
                                for own name, desc of btype.parameters ? { }
                                    if name[...8] isnt 'default '
                                        value = behavior[name] ? \
                                            btype.parameters["default
                                                #{name}"] ? ''
                                        controls.push
                                            type : 'text'
                                            value : "<p>#{desc}</p>"
                                            class : 'line-above'
                                        controls.push [
                                            type : 'text'
                                            value : "<b>#{name}:</b>"
                                        ,
                                            type : 'string input'
                                            name : "parameter #{name}"
                                            value : value
                                        ]
                                controls = controls.concat [
                                    type : 'action'
                                    value : 'Save'
                                    default : yes
                                    action : ( event ) =>
                                        for own key, value of event
                                            if key[...10] is 'parameter '
                                                behavior[key[10..]] = value
                                        object.save?()
                                        again()
                                ,
                                    type : 'action'
                                    value : 'Cancel'
                                    cancel : yes
                                    action : again
                                ,
                                    type : 'text'
                                    value : "<p>The behavior's description,
                                             for reference:</p>
                                             <div class='well'
                                             >#{btype.description}</div>"
                                ]
                                player.showUI controls
                    else
                        pair.push
                            type : 'text'
                            value : ''
                    pair.push
                        type : 'action'
                        value : 'Remove'
                        action : =>
                            object.behaviors.splice index, 1
                            object.save?()
                            again()
                    controls.push pair
            if object.behaviors.length is 0
                controls.push
                    type : 'text'
                    value : '(no behaviors attached to this object)'
            controls.push
                type : 'text'
                value : '<h4>Behaviors you can attach to the object:</h4>'
                class : 'line-above'
            before = controls.length
            for index in @entries()
                do ( index ) =>
                    behavior = @get index
                    if typeName in ( behavior.targets ? [ ] )
                        controls.push [
                            type : 'text'
                            value : behavior.name
                        ,
                            type : 'action'
                            value : 'Attach'
                            action : =>
                                object.behaviors.push \
                                    'behavior type' : index
                                object.save?()
                                again()
                        ]
            if controls.length is before
                controls.push
                    type : 'text'
                    value : '(no behaviors can be attached to the object)'
            controls.push
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback
            player.showUI controls

Installing behaviors may run code that calls `setInterval()`.  When the
objects on which the behaviors were installed are destroyed, we will want
the `setInterval()` calls to stop recurring.  Thus we create the following
API for creating, filling, and clearing lists of intervals.  They are used
by the behavior-installing functions, below.

        createIntervalSet : =>
            @intervalSets ?= { }
            i = 0
            while @intervalSets.hasOwnProperty i then i++
            @intervalSets[i] = [ ]
            i
        addToIntervalSet : ( index, interval ) =>
            @intervalSets?[index]?.push interval
        clearIntervalSet : ( index ) =>
            if not @intervalSets?[index]? then return
            clearInterval i for i in @intervalSets[index]
            delete @intervalSets[index]

The following function takes a code string and turns it into a function we
can run multiple times on multiple objects.

        makeCodeRunnable : ( codeString, author = null, argnames = [ ],
                intervalSetIndex = null ) =>
            result = require( 'acorn' ).parse codeString,
                { allowReturnOutsideFunction : true }
            functions =
                "function showAnimation ( loc, name, paramObj ) {
                    return require( './animations' )
                        .showAnimation( loc, name, paramObj );
                }
                function stopAnimation ( id ) {
                    require( './animations' ).stopAnimation( id );
                }
                function playSound ( name, target ) {
                    require( './sounds' ).playSound( name, target );
                }
                function Creature ( index ) {
                    var ctor = require( './creatures' ).Creature;
                    var result = new ctor( index );
                    return result.typeName ? result : null;
                }
                function Item ( index ) {
                    var ctor = require( './movableitems' ).MovableItem;
                    var result = new ctor( index, null );
                    return result.typeName ? result : null;
                }
                function livingsNear ( position, radius ) {
                    return require( './blocks' ).creaturesNearPosition(
                        position, radius ).concat(
                            require( './player' ).playersNearPosition(
                                position, radius ) );
                }
                function landscapeItemsNear ( position, radius ) {
                    if ( typeof( radius ) == 'undefined' ) radius = 1;
                    return require( './blocks' ).getItemsNearPoint(
                        position[0], position[1], position[2], radius );
                }
                function confirm ( player, text, yesAction, noAction ) {
                    require( './ui' ).areYouSure( player, text, yesAction,
                        noAction );
                }
                function getCell ( plane, x, y ) {
                    require( './blocks' ).getCell( plane, x, y );
                }
                function setCell ( plane, x, y, index ) {
                    return require( './blocks' )
                        .setCell( plane, x, y, index );
                }
                var loggedSetInterval = null;
                var random = require( './random' );"
            if author
                functions +=
                    "function log () {
                        require( './logs' ).logMessage( '#{author}',
                            Array.prototype.slice.apply( arguments )
                                .join( ' ' ) );
                    }"
                if intervalSetIndex? then functions +=
                    "loggedSetInterval = function () {
                        var func = arguments[0];
                        var clearCode;
                        arguments[0] = function () {
                            try {
                                func.apply( this, arguments );
                            } catch ( e ) {
                                clearInterval( clearCode );
                                require( './logs' ).logError( '#{author}',
                                    'code called by setInterval()' +
                                    ' -- line number may be unreliable',
                                    func+'', e );
                            }
                        };
                        clearCode = setInterval.apply( null, arguments );
                        require( './behaviors' ).addToIntervalSet(
                            #{intervalSetIndex}, clearCode );
                    };"
            declarations = ( "var #{identifier} = args.#{identifier};" \
                for identifier in argnames \
                when ' ' not in identifier ).join '\n'
            mayNotUse = [ 'require', 'process' ] # more later
            for identifier in mayNotUse
                declarations += "\nvar #{identifier} = null;"
            declarations += "\nvar setInterval = loggedSetInterval;"
            prefix = "( function ( args ) { #{declarations}\n"
            prefixLength = prefix.split( '\n' ).length - 1
            prefix = "#{functions}#{prefix}"
            codeString = prefix + codeString + '\n} )'
            try
                applyMe = eval codeString
                result = ( object, args ) -> applyMe.apply object, [ args ]
                result.prefixLength = prefixLength
                result
            catch e
                e.prefixLength = prefixLength
                throw e

The following function installs a behavior in an object by creating (or
loading from a cache) a runnable version of the behavior's code, then
running that code on the object.  The `behaviorData` parameter should be an
object created by the `editAttachments` routine above, which will contain
the member "behavior type" as well as members for each parameter specified
at the time of attachment.

        installBehavior : ( behaviorData, object ) =>
            return unless index = behaviorData['behavior type']
            return unless code = @get index, 'code'
            author = @getAuthors( index )[0]
            behaviorParameters = @get index, 'parameters'
            for own key, value of behaviorParameters
                if key[...8] is 'default ' and key[8..] not of behaviorData
                    behaviorData[key[8..]] = value
            try
                object.intervalSetIndex ?= @createIntervalSet()
                runnable = @makeCodeRunnable code, author,
                    Object.keys( behaviorParameters ? { } ),
                    object.intervalSetIndex
                runnable object, behaviorData
            catch e
                e.prefixLength ?= runnable?.prefixLength
                require( './logs' ).logError author,
                    "behavior #{@get index, 'name'}", code, e

## Exporting

The module then exports a single instance of the `BehaviorsTable` class.

    module.exports = new BehaviorsTable
