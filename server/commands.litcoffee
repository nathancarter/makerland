
# Commands Module

We will need the user interface module.

    ui = require './ui'

This module will define all the commands available to players.  The module
object will be a mapping from command names to objects defining the
command's properties (description, help, code to run it, etc.).

    module.exports =

## Basic Commands

The quit command logs the player out of the game.

        quit :
            category : 'basic'
            icon : 'quit.png'
            shortInfo : 'Leave the game immediately'
            help : 'This command saves your player\'s data, then
                immediately disconnects your browser from the game server.'
            run : ( player ) -> player.socket.disconnect()

The players command lists all players who have logged in.

        players :
            category : 'basic'
            icon : 'players.png'
            shortInfo : 'List all logged-in players'
            help : 'This command shows you an alphabetical list of the
                names of all players who have logged in.'
            run : ( player ) ->
                { Player } = require './player'
                names = ( p.name[0].toUpperCase() + p.name[1..] \
                    for p in Player::allPlayers when p.name? ).sort()
                toShow = [
                    type : 'text'
                    value : '<h3>Players logged in now:</h3>'
                ]
                teleport = ( mover, goal ) ->
                    require( './animations' ).showAnimation \
                        mover.getPosition(), 'teleport out',
                        center : mover.getPosition()
                    require( './sounds' ).playSound 'teleport',
                        mover.getPosition()
                    mover.teleport goal.getPosition()
                    require( './animations' ).showAnimation \
                        goal.getPosition(), 'teleport in',
                        center : goal.getPosition()
                    require( './sounds' ).playSound 'teleport',
                        goal.getPosition()
                for name in names
                    do ( name ) ->
                        if player.name is 'admin' and name isnt 'Admin'
                            toShow.push [
                                type : 'text'
                                value : name
                            ,
                                type : 'action'
                                value : 'Bring here'
                                action : =>
                                    if other = Player.nameToPlayer name
                                        teleport other, player
                                        player.showOK "Teleported #{name}
                                            here!"
                                    else
                                        player.showOK "#{name} seems to
                                            have logged out."
                            ,
                                type : 'action'
                                value : 'Go there'
                                action : =>
                                    if other = Player.nameToPlayer name
                                        teleport player, other
                                        player.showOK "Teleported you to
                                            #{name}!"
                                    else
                                        player.showOK "#{name} seems to
                                            have logged out."
                            ]
                        else
                            toShow.push
                                type : 'text'
                                value : name
                toShow.push
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : => player.showCommandUI()
                player.showUI toShow

The settings command allows players to edit their personal settings.

        settings :
            category : 'basic'
            icon : 'settings.png'
            shortInfo : 'Edit your player settings'
            help : 'This command shows you options that you can customize
                about your player, such as your password.'
            run : ( player ) ->
                do settings = ->
                    changePassword = ( event ) ->
                        accounts = require './accounts'
                        oldp = event['old password']
                        newp = event['new password']
                        newp2 = event['new password again']
                        if newp isnt newp2
                            return player.showOK 'New passwords did not
                                match.', settings
                        if not accounts.validLoginPair player.name, oldp
                            return player.showOK 'Incorrect password.',
                                settings
                        if not accounts.validPassword newp
                            return player.showOK 'Invalid password. ' \
                                + accounts.passwordRules
                        accounts.set player.name, 'password', newp
                        player.showOK 'Password changed!'
                    player.showUI
                        type : 'text'
                        value : "<h3>Settings for #{player.name}:</h3>"
                    ,
                        type : 'action'
                        value : 'Change password'
                        action : ->
                            player.showUI
                                type : 'text'
                                value : '<h3>Changing password</h3>'
                            ,
                                type : 'password input'
                                name : 'old password'
                            ,
                                type : 'password input'
                                name : 'new password'
                            ,
                                type : 'password input'
                                name : 'new password again'
                            ,
                                type : 'action'
                                value : 'Change'
                                default : yes
                                action : changePassword
                            ,
                                type : 'action'
                                value : 'Cancel'
                                cancel : yes
                                action : -> settings
                    ,
                        type : 'action'
                        value : 'Change appearance'
                        action : ->
                            player.showUI
                                type : 'text'
                                value : '<h3>Changing appearance</h3>'
                            ,
                                type : 'text'
                                value : '<center>Head</center>'
                            ,
                                type : 'choice'
                                name : 'head size'
                                choices :
                                    small : 0.07
                                    medium : 0.1
                                    large : 0.13
                                selected :
                                    player.saveData.avatar?.headSize ? 0.1
                            ,
                                type : 'choice'
                                name : 'head color'
                                choices : ui.colors
                                selected :
                                    player.saveData.avatar?.headColor ? \
                                    '#000000'
                            ,
                                type : 'choice'
                                name : 'hair color'
                                choices : ui.colors
                                selected :
                                    player.saveData.avatar?.hairColor ? \
                                    '#000000'
                            ,
                                type : 'choice'
                                name : 'hair style'
                                choices :
                                    none : 0
                                    short : 1
                                    medium : 2
                                    bob : 3
                                    shoulders : 4
                                    'very long' : 5
                                selected :
                                    player.saveData.avatar?.hairLength ? 0
                            ,
                                type : 'choice'
                                name : 'hair volume'
                                choices :
                                    thin : 0.5
                                    normal : 1
                                    thick : 1.5
                                    fluffy : 2
                                    'very fluffy' : 3
                                selected :
                                    player.saveData.avatar?.hairFluff ? 1
                            ,
                                type : 'text'
                                value : '<center>Body</center>'
                            ,
                                type : 'choice'
                                name : 'shoulders'
                                choices :
                                    narrow : 0.03
                                    normal : 0.06
                                    broad : 0.10
                                selected :
                                    player.saveData.avatar?.shouldersWidth \
                                    ? 0.03
                            ,
                                type : 'choice'
                                name : 'hips'
                                choices :
                                    narrow : 0.03
                                    normal : 0.06
                                    broad : 0.10
                                selected :
                                    player.saveData.avatar?.hipsWidth ? 0.03
                            ,
                                type : 'choice'
                                name : 'body color'
                                choices : ui.colors
                                selected :
                                    player.saveData.avatar?.bodyColor ? \
                                    '#000000'
                            ,
                                type : 'choice'
                                name : 'height'
                                choices :
                                    'very short' : 0.5
                                    short : 0.8
                                    normal : 1
                                    tall : 1.2
                                selected :
                                    player.saveData.avatar?.height ? 1
                            ,
                                type : 'text'
                                value : '<center>Limbs</center>'
                            ,
                                type : 'choice'
                                name : 'arm color'
                                choices : ui.colors
                                selected :
                                    player.saveData.avatar?.armColor ? \
                                    '#000000'
                            ,
                                type : 'choice'
                                name : 'leg color'
                                choices : ui.colors
                                selected :
                                    player.saveData.avatar?.legColor ? \
                                    '#000000'
                            ,
                                type : 'choice'
                                name : 'thickness'
                                choices :
                                    thin : 1
                                    normal : 2
                                    thick : 3
                                selected :
                                    player.saveData.avatar?.thickness ? 1
                            ,
                                type : 'action'
                                value : 'Done'
                                cancel : yes
                                action : settings
                            ,
                                type : 'watcher'
                                action : ( event ) ->
                                    player.saveData.avatar =
                                        headColor : event['head color']
                                        hairColor : event['hair color']
                                        bodyColor : event['body color']
                                        armColor : event['arm color']
                                        legColor : event['leg color']
                                        thickness : parseInt event.thickness
                                        hipsWidth : parseFloat event.hips
                                        shouldersWidth : parseFloat \
                                            event.shoulders
                                        height : parseFloat event.height
                                        headSize : parseFloat \
                                            event['head size']
                                        hairLength : parseFloat \
                                            event['hair style']
                                        hairFluff : parseFloat \
                                            event['hair volume']
                                    player.updateStatus()
                    ,
                        type : 'action'
                        value : 'Edit shortcuts'
                        action : ->
                            controls = [
                                type : 'text'
                                value : '<h3>Shortcuts</h3>
                                    <p>Use the tools below to edit your
                                    keyboard shortcuts for the game\'s
                                    commands, as well as shortcuts that sit
                                    as icons on top of the game map.</p>
                                    <p>Due to differences in browsers and
                                    keyboards, ordinary letters work best;
                                    punctuation and other symbols do not
                                    always work.</p>'
                            ]
                            shortcuts = player.saveData.shortcuts ?= { }
                            hudshorts = player.saveData.hudshorts ?= [ ]
                            commands = player.commands().concat [
                                hideshow = 'hide/show command panel'
                            ]
                            for command in commands
                                controls = controls.concat [
                                    type : 'category'
                                    name : command
                                ,
                                    [
                                        type : 'text'
                                        value : 'Keyboard shortcut:'
                                    ,
                                        type : 'string input'
                                        name : "shortcut for #{command}"
                                        value : shortcuts[command] or ''
                                    ]
                                ]
                                if command isnt hideshow
                                    controls.push
                                        type : 'checkbox'
                                        checked : command in hudshorts
                                        name : "Show #{command} over map"
                            controls = controls.concat [
                                type : 'action'
                                value : 'Save'
                                default : yes
                                action : ( data ) ->
                                    invalids = [ ]
                                    hudshorts = { }
                                    for command in commands
                                        sh = data["shortcut for #{command}"]
                                        ch = data[ \
                                            "Show #{command} over map"]
                                        if sh.length > 1
                                            invalids.push sh
                                        else if sh.length is 1
                                            shortcuts[command] = sh
                                        if ch
                                            hudshorts[command] =
                                                module.exports[command].icon
                                    player.saveData.hudshorts = hudshorts
                                    if invalids.length > 0
                                        player.showOK "One or more of your
                                            keyboard shortcuts was too long.
                                            The following keyboard shortcuts
                                            were not saved: #{invalids}",
                                            -> module.exports.settings.run \
                                                player
                                    else
                                        module.exports.settings.run player
                            ,
                                type : 'action'
                                value : 'Cancel'
                                cancel : yes
                                action : ->
                                    module.exports.settings.run player
                            ]
                            player.showUI controls
                    ,
                        type : 'action'
                        value : 'Done'
                        cancel : yes
                        action : -> player.showCommandUI()

The talk command asks the client to show the player's inputs to all the
other players in the immediate area (e.g., by speech bubbles).  But all it
does is trigger the animation; the completion of the visual is dependent
upon the contents of the animations database.

        talk :
            category : 'basic'
            icon : 'talk.png'
            shortInfo : 'Talk to the people nearby'
            help : 'This command lets you type in text messages that are
                shown to users around you through speech bubbles over your
                avatar\'s head.'
            run : ( player ) ->
                player.showUI
                    type : 'text'
                    value : '<h3>Talking</h3>
                             <p>Enter below what you want to say.
                             Press enter to speak, Esc to stop talking.</p>'
                ,
                    type : 'string input'
                    name : 'words to say'
                    maxlength : 60
                ,
                    type : 'action'
                    value : 'Speak'
                    default : yes
                    action : ( event ) ->
                        again = -> module.exports.talk.run player
                        position = player.getPosition()
                        text = event['words to say']
                        player.attempt 'speak', ->
                            require( './animations' ).showAnimation \
                                position, 'speak',
                                { text : text, speaker : player.name }
                            require( './sounds' ).playSound 'speech bling',
                                position
                            player.emit 'spoke', text
                            hearers = require( './blocks' ) \
                                .whoCanSeePosition position
                            for otherThing in hearers
                                if otherThing isnt player
                                    otherThing.emit 'heard',
                                        speech : text
                                        speaker : player
                            again()
                        , ( failReason ) ->
                            if typeof failReason isnt 'string'
                                failReason = 'You cannot speak!'
                            player.showOK failReason, again
                        ,
                            text
                ,
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : -> player.showCommandUI()

The inventory command shows you everything in your inventory.  It is smart
enough to check once per second whether the inventory has changed, and if
so, to refresh the view.

        inventory :
            category : 'basic'
            icon : 'inventory.png'
            shortInfo : 'See what you are carrying'
            help : 'This command lists all the items you are carrying, and
                lets you pick up or drop items on the ground nearby.  It
                also allows you to use items you are carrying.'
            run : ( player ) ->
                mi = require './movableitems'
                stuffNearby = ->
                    require( './blocks' ).movableItemsNearPosition \
                        player.getPosition(), 1
                player.inventoryBeingDisplayed =
                    player.inventory.slice().concat stuffNearby()
                refreshView = -> module.exports.inventory.run player
                maybeRefreshView = ->
                    if player.socket.connected and \
                       player.inventoryBeingDisplayed?
                        compare = player.inventory.slice().concat \
                            stuffNearby()
                        if player.inventoryBeingDisplayed.length isnt \
                           compare.length then return refreshView()
                        for i in [0...compare.length]
                            if player.inventoryBeingDisplayed[i] isnt \
                               compare[i] then return refreshView()
                        setTimeout maybeRefreshView, 500
                maybeRefreshView()
                contents = [
                    type : 'text'
                    value : '<h3>Your inventory:</h3>'
                ]
                for item in player.inventory
                    do ( item ) ->
                        contents.push [
                            type : 'text'
                            value : mi.normalIcon item.index
                        ,
                            type : 'text'
                            value : item.typeName
                        ,
                            type : 'action'
                            value : 'drop'
                            action : ->
                                item.attempt 'drop', ->
                                    item.move player.getPosition()
                                    refreshView()
                                , ( failReason ) ->
                                    if typeof failReason isnt 'string'
                                        failReason = 'You cannot drop it!'
                                    player.showOK failReason, refreshView
                                , player
                        ]
                        for own name, func of item.uses
                            if typeof func is 'function'
                                contents.push [
                                    type : 'text'
                                    value : ''
                                ,
                                    type : 'action'
                                    value : name
                                    action : ->
                                        try
                                            func.apply item
                                        catch e
                                            author = mi.getAuthors(
                                                item.index )[0]
                                            e.prefixLength = 4 # no idea why
                                            require( './logs' ).logError \
                                                author, "doing \"#{name}\"
                                                to \"#{item.typeName}\"",
                                                "#{func}", e
                                ]
                if contents.length is 1
                    contents.push { type : 'text', value : '(no items)' }
                contents.push
                    type : 'text'
                    value : '<h3>Items near you:</h3>'
                lastLength = contents.length
                for item in stuffNearby()
                    contents.push [
                        type : 'text'
                        value : require( './movableitems' ).normalIcon \
                            item.index
                    ,
                        type : 'text'
                        value : item.typeName
                    ,
                        type : 'action'
                        value : 'pick up'
                        action : ->
                            if not player.canCarry item
                                player.showOK 'You cannot carry that much.',
                                    refreshView
                                return
                            item.attempt 'get', ->
                                item.move player
                                refreshView()
                            , ( failReason ) ->
                                if typeof failReason isnt 'string'
                                    failReason = 'You cannot pick it up!'
                                player.showOK failReason, refreshView
                            , player
                    ]
                if contents.length is lastLength
                    contents.push { type : 'text', value : '(none)' }
                contents.push
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : ->
                        delete player.inventoryBeingDisplayed
                        player.showCommandUI()
                player.showUI contents

The inspect command allows the player to see other players' and creatures'
inventories, and interact with creature and landscape items.

        inspect :
            category : 'basic'
            icon : 'inspect.png'
            shortInfo : 'Inspect players, creatures, or items nearby'
            help : 'This command inspects the closest object to you, or lets
                you pick from a list if there are several.'
            run : ( player ) ->
                N = require( './settings' ).mapBlockSizeInCells
                pos = player.getPosition()
                bt = require './blocks'
                closeEnough = ( position ) ->
                    dx = position[1] - pos[1]
                    dy = position[2] - pos[2]
                    Math.sqrt( dx*dx + dy*dy ) < 2
                player.mapClickMode \
                    'Click on an item, creature, or player on the map to
                    inspect it.',
                    ( x, y ) ->
                        if not closeEnough [ pos[0], x, y ]
                            return player.showOK 'You cannot inspect things
                                that are so far away from you.'
                        landscape = bt.getItemsOverPoint pos[0], x, y
                        if not player.isMaker()
                            landscape = ( i for i in landscape when \
                                i.visible )
                        movables =
                            bt.movableItemsNearPosition [ pos[0], x, y ], 1
                        creatures =
                            bt.creaturesNearPosition [ pos[0], x, y ], 1
                        players = require( './player' ) \
                            .playersNearPosition [ pos[0], x, y ], 1
                        players = ( p for p in players when p isnt player )
                        results = landscape.concat( movables ) \
                            .concat( creatures ).concat( players )
                        if results.length is 1
                            results[0].gotInspectedBy player
                        else if results.length > 1
                            controls = [ ]
                            for thing in results
                                if thing is player then continue
                                do ( thing ) ->
                                    if thing in landscape
                                        icon =
                                            require( './landscapeitems' ) \
                                                .smallIcon thing.type
                                        name = thing.typeName
                                    else if thing in movables
                                        icon = require( './movableitems' ) \
                                            .normalIcon thing.index
                                        name = thing.typeName
                                    else if thing in creatures
                                        icon = require( './creatures' ) \
                                            .normalIcon thing.index
                                        name = thing.typeName
                                    else
                                        icon = 'Player'
                                        name = thing.name
                                    name = name[0].toUpperCase() + name[1..]
                                    controls.push [
                                        type : 'text'
                                        value : "<center>#{icon}</center>"
                                    ,
                                        type : 'text'
                                        value : name
                                    ,
                                        type : 'action'
                                        value : 'Inspect'
                                        action : ->
                                            thing.gotInspectedBy player
                                    ]
                            controls.unshift
                                type : 'text'
                                value : '<h3>Inspect which thing?</h3>'
                            controls.push
                                type : 'action'
                                value : 'Cancel'
                                cancel : yes
                                action : -> player.showCommandUI()
                            player.showUI controls
                    , ( -> player.showCommandUI() ), 'zoom-in'

## Maker Commands

The database command allows makers to browse the list of database tables,
browse each table, and edit those tables which are editable, including
adding, removing, and changing entries.

        database :
            category : 'maker'
            icon : 'database.png'
            shortInfo : 'Browse the game assets database'
            help : 'This command shows all tables in the database, and lets
                you click on any one to see its entries.  Some tables permit
                adding, removing, and editing the entries as well.'
            run : ( player ) ->
                database = require './database'
                do browseDB = ->
                    tableNames = database.tables
                    strcmp = ( a, b ) ->
                        if a < b then -1 else if a > b then 1 else 0
                    tableNames.sort ( a, b ) ->
                        strcmp database[a].humanReadableName,
                               database[b].humanReadableName
                    buttons = for name in tableNames
                        do ( name ) ->
                            table = database[name]
                            if table.browse?
                                browseTable = ->
                                    table.browse player, browseDB
                            capname = name[0].toUpperCase() + name[1..]
                            browseTable ?= ->
                                contents = [
                                    type : 'text'
                                    value : "<h3>#{capname} table:</h3>"
                                ]
                                hasEdit = 'edit' of table
                                hasRemove = 'remove' of table
                                hasDuplicate = table.duplicate
                                for entry in table.entries()
                                    do ( entry ) ->
                                        contents.push
                                            type : 'text'
                                            value : table.show entry
                                            class : 'line-above'
                                        entryActions = [ ]
                                        if hasEdit and table.canEdit \
                                                player, entry
                                            entryActions.push
                                                type : 'action'
                                                value : 'edit'
                                                action : -> table.edit \
                                                    player, entry, \
                                                    browseTable
                                        if hasRemove and table.canRemove \
                                                player, entry
                                            entryActions.push
                                                type : 'action'
                                                value : 'remove'
                                                action : -> table.remove \
                                                    player, entry, \
                                                    browseTable
                                        if hasDuplicate and table.canAdd \
                                                player
                                            entryActions.push
                                                type : 'action'
                                                value : 'copy'
                                                action : ->
                                                    table.duplicate \
                                                        player, entry,
                                                        browseTable
                                        if entryActions.length
                                            if entryActions.length < 3
                                                entryActions.unshift
                                                    type : 'text'
                                                    value : ''
                                            contents.push \
                                                entryActions.slice()
                                contents.push
                                    type : 'text'
                                    value : ''
                                    class : 'line-above'
                                if 'add' of table and table.canAdd player
                                    contents.push
                                        type : 'action'
                                        value : 'Add entry'
                                        action : ->
                                            table.add player, browseTable
                                    line = undefined
                                contents.push
                                    type : 'action'
                                    value : 'Done'
                                    cancel : yes
                                    action : browseDB
                                player.showUI contents
                            type : 'action'
                            value : table.humanReadableName
                            action : browseTable
                    buttons.unshift
                        type : 'text'
                        value : '<h3>Tables in Database:</h3>
                            <p>(Click one to view its contents.)</p>
                            <p>Need help?
                            <a href="docs/databasecommand.html"
                            target="_blank">Read this command\'s
                            full documentation.</a></p>'
                    buttons.push
                        type : 'action'
                        value : 'Done'
                        cancel : yes
                        action : -> player.showCommandUI()
                    player.showUI buttons

The world command allows the maker to edit the game world by clicking with
the mouse on the map itself.

        world :
            category : 'maker'
            icon : 'world.png'
            shortInfo : 'Edit the game world'
            help : 'This command allows the maker to edit the game map by
                choosing cell types, then clicking the map to fill the map
                with that type of cell.'
            run : ( player ) ->
                ctable = require( './database' ).celltypes
                itable = require( './database' ).landscapeitems
                cchooser = ctable.entryChooser player, 'cell type', 1
                ichooser = itable.entryChooser player, 'item type', 1
                fail = -> player.showOK 'You do not have permission to edit
                    this plane.  Create your own plane and edit its map.'
                bt = require './blocks'
                putCells = => player.showUI
                    type : 'text'
                    value : '<h3>Editing Map Cells</h3>'
                ,
                    cchooser( putCells )
                ,
                    type : 'action'
                    value : 'Place individual cells'
                    default : yes
                    action : ( data ) =>
                        choice = data['cell type']
                        if not ctable.exists choice
                            return player.showOK 'You must choose a valid
                                cell type first.', putCells
                        celltypename = ctable.get choice, 'name'
                        changeMapCell = ( x, y ) ->
                            plane = player.getPosition()[0]
                            if not bt.canEdit player, bt.planeKey plane
                                return fail()
                            bt.setCell plane, x, y, choice
                            require( './animations' ).showAnimation \
                                player.getPosition(), 'map edit',
                                { player : player.name, \
                                  location : [ plane, x, y ] }
                        player.mapClickMode "Click any cell on the map to
                            change it to be \"#{celltypename}.\"",
                            changeMapCell, putCells
                ,
                    type : 'action'
                    value : 'Fill rectangles of cells'
                    action : ( data ) =>
                        choice = data['cell type']
                        if not ctable.exists choice
                            return player.showOK 'You must choose a valid
                                cell type first.', putCells
                        celltypename = ctable.get choice, 'name'
                        firstCorner = ->
                            player.mapClickMode "Click the first corner of
                                the area to fill with \"#{celltypename}.\"",
                                secondCorner, putCells, 'nw-resize'
                        secondCorner = ( x, y ) ->
                            player.mapClickMode "Click the second corner of
                                the area to fill with \"#{celltypename}.\"",
                                fillRectangle( x, y ), putCells, 'se-resize'
                        fillRectangle = ( x1, y1 ) ->
                            ( x2, y2 ) ->
                                plane = player.getPosition()[0]
                                if not bt.canEdit player, bt.planeKey plane
                                    return fail()
                                if x1 > x2 then [ x1, x2 ] = [ x2, x1 ]
                                if y1 > y2 then [ y1, y2 ] = [ y2, y1 ]
                                x1 = ( Math.floor x1 ) | 0
                                x2 = ( Math.floor x2 ) | 0
                                y1 = ( Math.floor y1 ) | 0
                                y2 = ( Math.floor y2 ) | 0
                                for i in [x1..x2]
                                    for j in [y1..y2]
                                        bt.setCell plane, i, j, choice
                                firstCorner()
                                require( './animations' ).showAnimation \
                                    player.getPosition(), 'map edit',
                                    { player : player.name, \
                                      location : \
                                        [ plane, (x1+x2)/2, (y1+y2)/2 ] }
                        firstCorner()
                ,
                    type : 'action'
                    value : 'Rectangular border of cells'
                    action : ( data ) =>
                        choice = data['cell type']
                        if not ctable.exists choice
                            return player.showOK 'You must choose a valid
                                cell type first.', putCells
                        celltypename = ctable.get choice, 'name'
                        firstCorner = ->
                            player.mapClickMode "Click the first corner of
                                the area to fill with \"#{celltypename}.\"",
                                secondCorner, putCells, 'nw-resize'
                        secondCorner = ( x, y ) ->
                            player.mapClickMode "Click the second corner of
                                the area to fill with \"#{celltypename}.\"",
                                drawRectangle( x, y ), putCells, 'se-resize'
                        drawRectangle = ( x1, y1 ) ->
                            ( x2, y2 ) ->
                                plane = player.getPosition()[0]
                                if not bt.canEdit player, bt.planeKey plane
                                    return fail()
                                if x1 > x2 then [ x1, x2 ] = [ x2, x1 ]
                                if y1 > y2 then [ y1, y2 ] = [ y2, y1 ]
                                x1 = ( Math.floor x1 ) | 0
                                x2 = ( Math.floor x2 ) | 0
                                y1 = ( Math.floor y1 ) | 0
                                y2 = ( Math.floor y2 ) | 0
                                for i in [x1..x2]
                                    bt.setCell plane, i, y1, choice
                                    bt.setCell plane, i, y2, choice
                                for i in [y1..y2]
                                    bt.setCell plane, x1, i, choice
                                    bt.setCell plane, x2, i, choice
                                firstCorner()
                                require( './animations' ).showAnimation \
                                    player.getPosition(), 'map edit',
                                    { player : player.name, \
                                      location : \
                                        [ plane, (x1+x2)/2, (y1+y2)/2 ] }
                        firstCorner()
                ,
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : -> mainMenu()
                putItems = -> player.showUI
                    type : 'text'
                    value : '<h3>Adding landscape items</h3>'
                ,
                    ichooser( putItems )
                ,
                    type : 'action'
                    value : 'Place landscape items'
                    default : yes
                    action : ( data ) =>
                        choice = data['item type']
                        if not itable.exists choice
                            return player.showOK 'You must choose a valid
                                item type first.', putItems
                        itemtypename = itable.get choice, 'name'
                        addItem = ( x, y ) ->
                            plane = player.getPosition()[0]
                            if not bt.canEdit player, \
                                    bt.planeKey plane
                                return fail()
                            bt.addLandscapeItem plane, x, y, choice
                            require( './animations' ).showAnimation \
                                player.getPosition(), 'map edit',
                                { player : player.name, \
                                  location : [ plane, x, y ] }
                        player.mapClickMode "Click anywhere on the map to
                            add an instance of the item
                            \"#{itemtypename}.\"  But you cannot place the
                            item at the same location (or very close to) an
                            existing landscape item.", addItem, putItems
                ,
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : -> mainMenu()
                editItem = ( item ) ->
                    delta = 0.05
                    player.showUI
                        type : 'text'
                        value : '<h3>Editing landscape item</h3>'
                    ,
                        type : 'text'
                        value : "<p>You are editing the
                            \"#{item.typeName}\" at coordinates
                            (#{item.x},#{item.y}).</p>"
                    ,
                        type : 'action'
                        value : 'Edit behaviors'
                        action : ->
                            require( './behaviors' ).editAttachments \
                                player, item, changeItems
                    ,
                        type : 'text'
                        value : 'Move the item with these buttons:'
                    ,
                        [
                            type : 'text'
                            value : ' '
                        ,
                            type : 'action'
                            value : '&#8593;'
                            action : -> item.moveBy 0, -delta
                        ,
                            type : 'text'
                            value : ' '
                        ]
                    ,
                        [
                            type : 'action'
                            value : '&#8592;'
                            action : -> item.moveBy -delta, 0
                        ,
                            type : 'text'
                            value : ' '
                        ,
                            type : 'action'
                            value : '&#8594;'
                            action : -> item.moveBy delta, 0
                        ]
                    ,
                        [
                            type : 'text'
                            value : ' '
                        ,
                            type : 'action'
                            value : '&#8595;'
                            action : -> item.moveBy 0, delta
                        ,
                            type : 'text'
                            value : ' '
                        ]
                    ,
                        type : 'action'
                        value : 'Delete it'
                        action : ->
                            bt.removeLandscapeItem item.plane,
                                item.x, item.y
                            changeItems()
                    ,
                        type : 'action'
                        value : 'Done'
                        cancel : yes
                        action : -> changeItems()
                changeItems = ->
                    player.mapClickMode \
                        'Click on a landscape item on the map to edit it.',
                        ( x, y ) ->
                            items = bt.getItemsOverPoint \
                                player.getPosition()[0], x, y
                            if items.length is 1
                                editItem items[0]
                            else if items.length > 1
                                controls = [ ]
                                for item in items
                                    do ( item ) ->
                                        controls = controls.concat [
                                            type : 'text'
                                            value : "#{item.typeName}
                                                at coordinates
                                                (#{item.x},#{item.y})"
                                        ,
                                            type : 'action'
                                            value : 'Edit this one'
                                            action : -> editItem item
                                        ]
                                controls.unshift
                                    type : 'text'
                                    value : '<h3>Which one?</h3>
                                        <p>You clicked on or near several
                                        landscape items.  Which do you want
                                        to edit?</p>'
                                controls.push
                                    type : 'action'
                                    value : 'Cancel'
                                    cancel : yes
                                    action : -> changeItems()
                                player.showUI controls
                        , -> mainMenu()
                do mainMenu = -> player.showUI
                    type : 'text'
                    value : '<h3>Editing game world</h3>
                            <p>Need help?
                            <a href="docs/worldcommand.html"
                            target="_blank">Read this command\'s
                            full documentation.</a></p>'
                ,
                    type : 'action'
                    value : 'Change cells in map'
                    action : putCells
                ,
                    type : 'action'
                    value : 'Put landscape items on map'
                    action : putItems
                ,
                    type : 'action'
                    value : 'Edit landscape items on map'
                    action : changeItems
                ,
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : -> player.showCommandUI()

The teleport command allows the maker to mark locations in the world to
remember, then jump back to those locations later.

        teleport :
            category : 'maker'
            icon : 'teleport.png'
            shortInfo : 'Teleport (or edit your teleport list)'
            help : 'This command keeps track of all the places in the game
                world you\'ve memorized as teleportation destinations.  It
                lets you jump to one, add one, or remove one.'
            run : ( player ) ->
                showList = -> module.exports.teleport.run player
                tp = player.saveData.teleport ?= { }
                controls = [
                    type : 'text'
                    value : '<h3>Teleportation Destinations</h3>
                            <p>Need help?
                            <a href="docs/teleportcommand.html"
                            target="_blank">Read this command\'s
                            full documentation.</a></p>'
                ]
                if Object.keys( tp ).length > 0
                    for own key, value of tp
                        do ( key, value ) ->
                            controls.push [
                                type : 'text'
                                value : key
                            ,
                                type : 'action'
                                value : 'Go here'
                                action : ->
                                    require( './animations' ) \
                                        .showAnimation \
                                        player.getPosition(),
                                        'teleport out',
                                        center : player.getPosition()
                                    require( './sounds' ).playSound \
                                        'teleport', player.getPosition()
                                    player.teleport value
                                    require( './animations' ) \
                                        .showAnimation value, 'teleport in',
                                        center : value
                                    require( './sounds' ).playSound \
                                        'teleport', value
                                    showList()
                            ,
                                type : 'action'
                                value : 'Delete'
                                action : ->
                                    ui = require './ui'
                                    ui.areYouSure player, "delete forever
                                        your memorized destination called
                                        \"#{key}\"",
                                        ( ->
                                            delete tp[key]
                                            player.showOK 'Deleted!',
                                                showList
                                        ), showList
                            ]
                else
                    controls.push
                        type : 'text'
                        value : 'You have not yet memorized any
                            teleportation destinations.'
                controls = controls.concat [
                    type : 'text'
                    value : 'To memorize your current location, type a name
                        for it in the box below, then click Add.'
                ,
                    [
                        type : 'string input'
                        name : 'type name here'
                    ,
                        type : 'action'
                        value : 'Add'
                        action : ( data ) ->
                            name = data['type name here']
                            if tp.hasOwnProperty name
                                player.showOK 'You are already using that
                                    destination name.  Try another.',
                                    showList
                            tp[name] = player.getPosition()
                            player.showOK "You have memorized your current
                                location as \"#{name}.\"", showList
                    ]
                ,
                    type : 'action'
                    value : 'Teleport to origin'
                    action : =>
                        require( './animations' ).showAnimation \
                            player.getPosition(), 'teleport out',
                            center : player.getPosition()
                        require( './sounds' ).playSound 'teleport',
                            player.getPosition()
                        player.teleport [ 0, 0, 0 ]
                        require( './animations' ).showAnimation [ 0, 0, 0 ],
                            'teleport in', center : [ 0, 0, 0 ]
                        require( './sounds' ).playSound 'teleport',
                            [ 0, 0, 0 ]
                        showList()
                ,
                    type : 'action'
                    value : 'Teleport on screen'
                    action : =>
                        player.mapClickMode \
                            'Click anywhere on screen to teleport there.
                            This will fail if you click a location at which
                            players are not permitted to stand (e.g.,
                            inside a wall, or in water.)',
                            ( x, y ) ->
                                plane = player.getPosition()[0]
                                require( './animations' ).showAnimation \
                                    player.getPosition(), 'teleport out',
                                    center : player.getPosition()
                                require( './sounds' ).playSound 'teleport',
                                    player.getPosition()
                                player.teleport [ plane, x, y ]
                                require( './animations' ).showAnimation \
                                    [ plane, x, y ],
                                    'teleport in', center : [ plane, x, y ]
                                require( './sounds' ).playSound 'teleport',
                                    [ plane, x, y ]
                            , -> player.showCommandUI()
                ,
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : => player.showCommandUI()
                ]
                player.showUI controls

The reset command deletes all landscape items in all blocks visible to the
maker, and recreates them all from scratch.  This has the advantage of also
reinstalling all their behaviors, which will thus be updated to the latest
versions.

        reset :
            category : 'maker'
            icon : 'reset.png'
            shortInfo : 'Reset the items near you in the map'
            help : 'This command destroys and instantly recreates all items
                that belong on the map near you.  This also reinstalls any
                behaviors in them, thus updating them to the latest versions
                of those behaviors.  It does nothing to map cells, only to
                items that sit on top of the map.'
            run : ( player ) ->
                require( './blocks' ).resetBlocksNearPlayer player
                player.showOK '<p>The objects near you have been reset.</p>
                    <p>Not sure what that means?
                    <a href="docs/resetcommand.html"
                    target="_blank">Read this command\'s
                    full documentation.</a></p>',
                    => player.showCommandUI()
