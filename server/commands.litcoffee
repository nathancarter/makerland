
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
                                selected : player.saveData.avatar.headColor
                            ,
                                type : 'choice'
                                name : 'body color'
                                choices : colors
                                selected : player.saveData.avatar.bodyColor
                            ,
                                type : 'choice'
                                name : 'arm color'
                                choices : colors
                                selected : player.saveData.avatar.armColor
                            ,
                                type : 'choice'
                                name : 'leg color'
                                choices : colors
                                selected : player.saveData.avatar.legColor
                            ,
                                type : 'choice'
                                name : 'thickness'
                                choices :
                                    thin : 1
                                    normal : 2
                                    thick : 3
                                selected : player.saveData.avatar.thickness
                            ,
                                type : 'choice'
                                name : 'height'
                                choices :
                                    'very short' : 0.5
                                    short : 0.8
                                    normal : 1
                                    tall : 1.2
                                selected : player.saveData.avatar.height
                            ,
                                type : 'choice'
                                name : 'head size'
                                choices :
                                    small : 0.07
                                    medium : 0.1
                                    large : 0.13
                                selected : player.saveData.avatar.headSize
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
                        value : 'Done'
                        action : -> player.showCommandUI()

## Maker Commands

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
                                for entry in table.entries()
                                    do ( entry ) ->
                                        contents.push
                                            type : 'text'
                                            value : table.show entry
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
                                        if entryActions.length
                                            entryActions.unshift
                                                type : 'text'
                                                value : ''
                                            contents.push \
                                                entryActions.slice()
                                if 'add' of table and table.canAdd player
                                    contents.push
                                        type : 'action'
                                        value : 'Add entry'
                                        action : ->
                                            table.add player, browseTable
                                contents.push
                                    type : 'action'
                                    value : 'Done'
                                    action : browseDB
                                player.showUI contents
                    buttons.unshift
                        type : 'text'
                        value : '<h3>Tables in Database:</h3>
                            <p>(Click one to view its contents.)</p>'
                    buttons.push
                        type : 'action'
                        value : 'Done'
                        action : -> player.showCommandUI()
                    player.showUI buttons
