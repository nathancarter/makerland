
# Commands Module

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
                list = ( require './player' ).Player::allPlayers
                names = ( p.name[0].toUpperCase() + p.name[1..] \
                    for p in list when p.name? ).sort()
                names.unshift '<h3>Players logged in now:</h3>'
                player.showOK names

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
                            colors =
                                white    : '#FFFFFF'
                                black    : '#000000'
                                dark     : '#313131'
                                gray     : '#626262'
                                tan      : '#7E715D'
                                dusty    : '#574C3C'
                                orange   : '#943E0F'
                                brown    : '#5F472F'
                                honey    : '#99761B'
                                gold     : '#C9BC0F'
                                algae    : '#769028'
                                grass    : '#397628'
                                trees    : '#246024'
                                sky      : '#28726E'
                                royal    : '#800080'
                                lavender : '#EFA9FE'
                                camo     : '#59955C'
                                russet   : '#8E2323'
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
                                choices : colors
                                selected :
                                    player.saveData.avatar?.headColor ? \
                                    '#000000'
                            ,
                                type : 'choice'
                                name : 'hair color'
                                choices : colors
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
                                choices : colors
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
                                choices : colors
                                selected :
                                    player.saveData.avatar?.armColor ? \
                                    '#000000'
                            ,
                                type : 'choice'
                                name : 'leg color'
                                choices : colors
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
                    buttons = for name in database.tables.sort()
                        do ( name ) ->
                            table = database[name]
                            if table.browse?
                                browseTable = ->
                                    table.browse player, browseDB
                            browseTable ?= ->
                                contents = [
                                    type : 'text'
                                    value : "<h3>#{name} table:</h3>"
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
                            <p>(Click one to view its contents.)</p>'
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
                            if not bt.canEdit player, \
                                    bt.planeKey player.getPosition()[0]
                                return fail()
                            bt.setCell player.getPosition()[0], x, y, choice
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
                            if not bt.canEdit player, \
                                    bt.planeKey player.getPosition()[0]
                                return fail()
                            bt.addLandscapeItem player.getPosition()[0],
                                x, y, choice
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
                    value : '<h3>Editing game world</h3>'
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
                    value : '<h3>Teleportation Destinations</h3>'
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
                                    player.teleport value
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
                    action : => player.teleport [ 0, 0, 0 ] ; showList()
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
                player.showOK 'The objects near you have been reset.',
                    => player.showCommandUI()
