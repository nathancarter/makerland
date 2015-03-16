
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
                                value : '<h4>Changing password</h4>'
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
                                black  : '#000000'
                                tan    : '#7E715D'
                                dusty  : '#574C3C'
                                orange : '#943E0F'
                                brown  : '#5F472F'
                                gray   : '#626262'
                                honey  : '#99761B'
                                gold   : '#C9BC0F'
                                algae  : '#769028'
                                grass  : '#397628'
                                trees  : '#246024'
                                sky    : '#28726E'
                            player.showUI
                                type : 'text'
                                value : '<h4>Changing appearance</h4>'
                            ,
                                type : 'choice'
                                name : 'head color'
                                choices : colors
                                selected : player.saveData.avatar?.headColor
                            ,
                                type : 'choice'
                                name : 'body color'
                                choices : colors
                                selected : player.saveData.avatar?.bodyColor
                            ,
                                type : 'choice'
                                name : 'arm color'
                                choices : colors
                                selected : player.saveData.avatar?.armColor
                            ,
                                type : 'choice'
                                name : 'leg color'
                                choices : colors
                                selected : player.saveData.avatar?.legColor
                            ,
                                type : 'choice'
                                name : 'thickness'
                                choices :
                                    thin : 1
                                    normal : 2
                                    thick : 3
                                selected : player.saveData.avatar?.thickness
                            ,
                                type : 'choice'
                                name : 'height'
                                choices :
                                    'very short' : 0.5
                                    short : 0.8
                                    normal : 1
                                    tall : 1.2
                                selected : player.saveData.avatar?.height
                            ,
                                type : 'choice'
                                name : 'head size'
                                choices :
                                    small : 0.07
                                    medium : 0.1
                                    large : 0.13
                                selected : player.saveData.avatar?.headSize
                            ,
                                type : 'action'
                                value : 'Done'
                                action : settings
                            ,
                                type : 'watcher'
                                action : ( event ) ->
                                    player.saveData.avatar =
                                        headColor : event['head color']
                                        bodyColor : event['body color']
                                        armColor : event['arm color']
                                        legColor : event['leg color']
                                        thickness : parseInt event.thickness
                                        height : parseFloat event.height
                                        headSize : parseFloat \
                                            event['head size']
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
                                'hide/show command panel'
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
                                ,
                                    type : 'checkbox'
                                    checked : command in hudshorts
                                    name : "Show #{command} over map"
                                ]
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
                    buttons = for name in database.tables
                        do ( name ) ->
                            table = database[name]
                            name = name[0].toUpperCase() + name[1..]
                            type : 'action'
                            value : name
                            action : browseTable = ->
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
                table = require( './database' ).celltypes
                chooser = table.entryChooser player, 'cell type', 1
                fail = -> player.showOK 'You do not have permission to edit
                    this plane.  Create your own plane and edit its map.'
                bt = require './blocks'
                do pick = => player.showUI
                    type : 'text'
                    value : '<h3>Editing Game Map</h3>'
                ,
                    chooser( pick )
                ,
                    type : 'action'
                    value : 'Place individual cells'
                    default : yes
                    action : ( data ) =>
                        choice = data['cell type']
                        if not table.exists choice
                            return player.showOK 'You must choose a valid
                                cell type first.', pick
                        celltypename = table.get choice, 'name'
                        changeMapCell = ( x, y ) ->
                            if not bt.canEdit player, \
                                    bt.planeKey player.position[0]
                                return fail()
                            bt.setCell player.position[0], x, y, choice
                        player.mapClickMode "Click any cell on the map to
                            change it to be \"#{celltypename}.\"",
                            changeMapCell, pick
                ,
                    type : 'action'
                    value : 'Fill rectangles of cells'
                    action : ( data ) =>
                        choice = data['cell type']
                        if not table.exists choice
                            return player.showOK 'You must choose a valid
                                cell type first.', pick
                        celltypename = table.get choice, 'name'
                        firstCorner = ->
                            player.mapClickMode "Click the first corner of
                                the area to fill with \"#{celltypename}.\"",
                                secondCorner, pick, 'nw-resize'
                        secondCorner = ( x, y ) ->
                            player.mapClickMode "Click the second corner of
                                the area to fill with \"#{celltypename}.\"",
                                fillRectangle( x, y ), pick, 'se-resize'
                        fillRectangle = ( x1, y1 ) ->
                            ( x2, y2 ) ->
                                plane = player.position[0]
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
                        if not table.exists choice
                            return player.showOK 'You must choose a valid
                                cell type first.', pick
                        celltypename = table.get choice, 'name'
                        firstCorner = ->
                            player.mapClickMode "Click the first corner of
                                the area to fill with \"#{celltypename}.\"",
                                secondCorner, pick, 'nw-resize'
                        secondCorner = ( x, y ) ->
                            player.mapClickMode "Click the second corner of
                                the area to fill with \"#{celltypename}.\"",
                                drawRectangle( x, y ), pick, 'se-resize'
                        drawRectangle = ( x1, y1 ) ->
                            ( x2, y2 ) ->
                                plane = player.position[0]
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
                            tp[name] = player.position.slice()
                            player.showOK "You have memorized your current
                                location as \"#{name}.\"", showList
                    ]
                ,
                    type : 'action'
                    value : 'Done'
                    cancel : yes
                    action : => player.showCommandUI()
                ]
                player.showUI controls
