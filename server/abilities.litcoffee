
# Abilities Table

This module implements a game database table for storing abilities, which
are blocks of code that can be run by players as commands, if the player has
learned the ability in question.

    { Table } = require './table'

It does so by subclassing the main Table class and adding ability-specific
functionality.

    class AbilitiesTable extends Table

## Constructor

The constructor sets the name of the table, then some defaults.  After that,
it does its most important function, which is that it installs all known
abilities into the commands module.

        constructor : () ->
            super 'abilities'
            @setDefault 'category', 'abilities'
            @setDefault 'shortInfo', 'an ability'
            @setDefault 'help', ''
            @setDefault 'code', ''
            @installAbility index for index in @entries()

## Maker Database Browsing

Implement custom show method.

        show : ( entry ) =>
            data = @get entry
            "<p>#{entry}. #{@smallIcon entry} #{data.name}
            (\"#{data.shortInfo},\" in category \"#{data.category}\")</p>"

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
            @set "#{i}", name : 'new ability'
            @lastAbilityAdded = "#{i}"
            @setAuthors "#{i}", [ player.name ]
            @installAbility "#{i}"
            player.showOK "The new ability was created with index #{i}.
                You have been set as its only author.
                Feel free to edit it to suit your needs.",
                -> callback "#{i}"

When duplicating an entry, we must ensure it has a different name that the
original, or we will have bugs in the admin's command list.  So we override
the default implementation of `duplicate`, and all we do is modify the name
after the duplication.  The following doesn't guarantee uniqueness, but it
will do the right thing in most situations.  Note that `@lastAbilityAdded`
is set in `add`, above.

        duplicate : ( player, entry, uiCallback ) =>
            super player, entry, =>
                @set @lastAbilityAdded, 'name',
                    "Copy of #{@get @lastAbilityAdded, 'name'}"
                @installAbility entry
                uiCallback()

You can edit an ability if you're one of its authors, which is the default
implementation of `canEdit`, so we have no need to override that.  The UI
for doing so looks like the following.

        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            data = @get entry
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h3>Editing ability #{entry},
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
                            value : "<h3>Changing name of ability
                                #{entry}:</h3>"
                        ,
                            type : 'string input'
                            name : 'new ability name'
                        ,
                            type : 'action'
                            value : 'Change name'
                            default : yes
                            action : ( event ) =>
                                newname = event['new ability name']
                                if not /[a-z]/.test newname
                                    return player.showOK 'New name must
                                        contain at least one letter.', again
                                @set entry, 'name', newname
                                player.showOK "Name of ability #{entry}
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
                            "<p>An ability's icon, just like any command's
                            icon, is an image of size 32x32.  Do not upload
                            larger icons; they will not fit correctly in the
                            UI.</p>",
                            again, ( contents ) =>
                                @setFile entry, 'icon', contents
                ]
            ,
                [
                    type : 'text'
                    value : 'Category:'
                ,
                    type : 'text'
                    value : data.category
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing category of ability
                                #{entry}:</h3>
                                <p>An ability's category is the heading
                                under which it falls in the
                                player's main list of commands.</p>"
                        ,
                            type : 'string input'
                            name : 'new category'
                        ,
                            type : 'action'
                            value : 'Change category'
                            default : yes
                            action : ( event ) =>
                                newcat = event['new category']
                                @set entry, 'category', newcat
                                player.showOK "Category for ability
                                    #{entry} changed to \"#{newcat}.\"",
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
                    value : 'Short info:'
                ,
                    type : 'text'
                    value : data.shortInfo
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing short info of ability
                                #{entry}:</h3>
                                <p>An ability's short info is the brief bit
                                of text that appears next to its icon on the
                                player's main list of commands.</p>"
                        ,
                            type : 'string input'
                            name : 'new short info'
                        ,
                            type : 'action'
                            value : 'Change short info'
                            default : yes
                            action : ( event ) =>
                                newinfo = event['new short info']
                                @set entry, 'shortInfo', newinfo
                                player.showOK "Short info for ability
                                    #{entry} changed to \"#{newinfo}.\"",
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
                    value : 'Help text:'
                ,
                    type : 'text'
                    value : data.help
                ,
                    type : 'action'
                    value : 'Change'
                    action : =>
                        player.showUI
                            type : 'text'
                            value : "<h3>Changing help text of ability
                                #{entry}:</h3>
                                <p>An ability's help text is shown when the
                                player hovers their mouse over the ability's
                                command button.  It may be as much as one or
                                two sentences.</p>"
                        ,
                            type : 'string input'
                            name : 'new help text'
                        ,
                            type : 'action'
                            value : 'Change help text'
                            default : yes
                            action : ( event ) =>
                                newhelp = event['new help text']
                                @set entry, 'help', newhelp
                                player.showOK "Help text for ability
                                    #{entry} changed to \"#{newhelp}.\"",
                                    again
                        ,
                            type : 'action'
                            value : 'Cancel'
                            cancel : yes
                            action : again
                ]
            ,
                type : 'action'
                value : 'Edit implementation'
                action : =>
                    player.showUI
                        type : 'text'
                        value : "<h3>Changing implementation of ability
                            #{entry}:</h3>"
                    ,
                        type : 'code input'
                        name : 'new implementation'
                        value : data.code
                    ,
                        type : 'text'
                        value : '<p>Not sure how to write this code?
                            <a href="docs/coding.html#abilities"
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
                action : => @installAbility entry ; callback()

A maker can remove an ability if and only if that maker can edit it.

        canRemove : ( player, entry ) => @canEdit player, entry
        remove : ( player, entry, callback ) =>
            action = =>
                name = @get entry, 'name'
                result = @tryToRemove entry
                if not @exists entry then @uninstallAbility name
                player.showOK result, callback
            require( './ui' ).areYouSure player,
                "remove the ability #{entry} <i>permanently</i>.
                 This action <i>cannot</i> be undone!  If there are any
                 players using this ability in the game, they may wonder
                 why it disappears!", action, callback

## Installing Abilities in the Commands Module

The following function takes a code string and turns it into a function we
can run multiple times on multiple objects.  It is a slightly simplified
version of what's in the Behaviors module.

        makeCodeRunnable : ( codeString, author = null ) =>
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
                function asymptotic ( y0, yinf, midx, stat ) {
                    return (yinf-y0)*Math.atan(stat/midx)/(Math.PI/2)+y0;
                }
                var random = require( './random' );"

The new functon above (different from behaviors) is "asymptotic."
It has the following properties, which are useful for computing the benefits
of an infinitely-upgradeable statistic.
asymptotic(y0,yinf,midx,0)=y0
asymptotic(y0,yinf,midx,x)->yinf as x->infinity
asymptotic(y0,yinf,midx,midx)=(y0+yinf)/2

            if author
                functions +=
                    "function log () {
                        require( './logs' ).logMessage( '#{author}',
                            Array.prototype.slice.apply( arguments )
                                .join( ' ' ) );
                    }"
            declarations = ''
            mayNotUse = [ 'require', 'process' ] # more later
            for identifier in mayNotUse
                declarations += "\nvar #{identifier} = null;"
            prefix = "( function ( args ) { #{declarations}\n"
            prefixLength = prefix.split( '\n' ).length - 1
            prefix = "#{functions}#{prefix}"
            codeString = prefix + codeString + '\n} )'
            try
                applyMe = eval codeString
                result = ( playerObject ) -> applyMe.apply playerObject, [ ]
                result.prefixLength = prefixLength
                result
            catch e
                e.prefixLength = prefixLength
                throw e

The following function runs a given ability for the given player.

        runAbility : ( abilityIndex, playerObject ) =>
            return unless @exists abilityIndex
            ability = @get abilityIndex
            return unless ability.code
            author = @getAuthors( abilityIndex )[0]
            try
                runnable = @makeCodeRunnable ability.code, author
                runnable playerObject
            catch e
                e.prefixLength ?= runnable?.prefixLength
                require( './logs' ).logError author,
                    "ability #{abilityIndex} (#{ability.name})",
                    ability.code, e

Now we can use both of those tools to install an ability into the commands
module, with the following function.

        installAbility : ( abilityIndex ) =>
            return unless @exists abilityIndex
            commands = require './commands'
            ability = @get abilityIndex
            commands[ability.name] =
                category : ability.category
                ability : yes
                icon : require( './database' ).createDatabaseURL \
                    'abilities', abilityIndex, 'icon'
                shortInfo : ability.shortInfo
                help : ability.help
                run : ( player ) => @runAbility abilityIndex, player
        uninstallAbility : ( abilityName ) =>
            commands = require './commands'
            delete commands[abilityName]

And whenever an ability name changes, we have to uninstall and reinstall it
in the commands module.

        set : ( entryName, A, B ) =>
            if A is 'name'
                oldname = @get entryName, 'name'
                @uninstallAbility oldname
            super entryName, A, B
            if A is 'name'
                @installAbility entryName

## Exporting

The module then exports a single instance of the `AbilitiesTable` class.

    module.exports = new AbilitiesTable
