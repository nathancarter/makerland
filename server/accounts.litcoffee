
# Player Accounts Table

This module implements a game database table for storing player accounts.

    { Table } = require './table'
    hash = require 'password-hash'

It does so by subclassing the main Table class and adding account-specific
functionality.

    class AccountsTable extends Table

## Constructor

The constructor ensures that an admin account exists in the table.

        constructor : () ->
            super 'accounts'
            if not @exists 'admin' then @createAccount 'admin', 'admin'

## Overriding `set`

If the password is what's being set, hash it first.

        set : ( entryName, A, B ) =>
            if A is 'password' then B = hash.generate B
            super entryName, A, B

## Accounts-Specific Functions

Is the given name a valid player name?  If so, return it in canonical form
(all lower case letters).  If not, return false.

        validUsername : ( username ) ->
            if typeof username isnt 'string' then return no
            username = username.toLowerCase()
            if not /^[a-z]{3,}$/.test username then return no
            username
        usernameRules : 'A username must have only the letters A through Z,
            and must be at least 3 letters long.'

Is the given password a valid password?  Return true or false.  Valid
passwords are anything containing at least 5 letters.

        validPassword : ( password ) -> password.length > 5
        passwordRules : 'A password must have at least 5 characters in it.'

This method allows checking to see if a username-password pair is valid.
It should return false if the username doesn't exist, because the hashed
password fetched from the database will be undefined.

        validLoginPair : ( username, password ) =>
            if not @validUsername username then return no
            if not @validPassword password then return no
            hashedPassword = @get username, 'password'
            if not hashedPassword? then return no
            hash.verify password, hashedPassword

This method creates a new player account.  It throws an error if the account
already exists.

        create : ( username, password ) =>
            if not @validUsername username
                throw @usernameRules
            if not @validPassword password
                throw @passwordRules
            if @exists username
                throw 'Account already exists: ' + username
            @set username, { }
            @set username, 'password', password

## Maker Permissions

Only the admin can edit individual player entries in the table.  The UI for
doing so looks like the following.

        canEdit : ( player, entry ) => player.name is 'admin'
        edit : ( player, entry, callback = -> player.showCommandUI() ) =>
            { Player } = require './player'
            warning = if Player.nameToPlayer entry
                "<p><font color='red'>Warning:</font>
                Cannot edit \"#{entry}\" because that player is currently
                playing the game.</p>"
            else
                ''
            again = => @edit player, entry, callback
            player.showUI
                type : 'text'
                value : "<h4>Editing account for \"#{entry}\":</h4>
                        #{warning}"
            ,
                type : 'action'
                value : 'Change name'
                action : =>
                    player.showUI
                        type : 'text'
                        value : "<h3>Changing name of \"#{entry}\":</h3>"
                    ,
                        type : 'string input'
                        name : 'new player name'
                    ,
                        type : 'action'
                        value : 'Change name'
                        default : yes
                        action : ( event ) =>
                            newname = event['new player name']
                            if not @validUsername newname
                                return player.showOK 'That username is not
                                    valid. ' + @usernameRules, again
                            if @exists newname
                                return player.showOK 'That username is
                                    already taken.', again
                            if Player.nameToPlayer entry
                                return player.showOK 'You cannot change a
                                    player\'s name while that player is
                                    logged in.', again
                            fs = require 'fs'
                            origfile = @filename entry
                            newfile = @filename newname
                            try
                                fs.renameSync origfile, newfile
                                player.showOK "Success.  Player renamed from
                                    #{entry} to #{newname}.", callback
                            catch e
                                player.showOK "Error.  Rename unsuccessful:
                                    #{e}", again
                    ,
                        type : 'action'
                        value : 'Cancel'
                        cancel : yes
                        action : again
            ,
                type : 'action'
                value : 'Reset password'
                action : =>
                    player.showUI
                        type : 'text'
                        value : "<h3>Resetting password for #{entry}:</h3>"
                    ,
                        type : 'password input'
                        name : 'enter new password'
                    ,
                        type : 'action'
                        value : 'Change password'
                        default : yes
                        action : ( event ) =>
                            newpass = event['enter new password']
                            if not @validPassword newpass
                                return player.showOK 'Invalid password. ' \
                                    + @passwordRules, again
                            if Player.nameToPlayer entry
                                return player.showOK 'You cannot change a
                                    player\'s password while that player is
                                    logged in.', again
                            @set entry, 'password', newpass
                            player.showOK 'Password successfully changed.',
                                again
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

Only the admin can remove individual player entries from the table.  The UI
for doing so looks like the following.

        canRemove : ( player, entry ) => player.name is 'admin'
        remove : ( player, entry, callback = -> player.showCommandUI() ) =>
            { Player } = require './player'
            if Player.nameToPlayer entry
                return player.showOK 'You cannot remove that player because
                    they are currently logged into the game.', callback
            action = =>
                if Player.nameToPlayer entry
                    return player.showOK 'You cannot remove that player
                        because they are currently logged into the game.',
                        callback
                player.showOK @tryToRemove( entry ), callback
            require( './ui' ).areYouSure player,
                "remove the player account \"#{entry}\" <i>permanently</i>.
                 This action <i>cannot</i> be undone!", action, callback

Only the admin can add new player entries to the table.  The UI for doing so
looks like the following.

        canAdd : ( player ) => player.name is 'admin'
        add : ( player, callback = -> player.showCommandUI() ) =>
            randomchar = ->
                'abcdefghijklmnopqrstuvwxyz'[(Math.random()*26)|0]
            newname = 'newplayer'
            while @exists newname
                newname += randomchar()
            password = ''
            while password.length < 10
                password += randomchar()
            @create newname, password
            player.showOK "A new account was created with the name
                <b>#{newname}</b>.  Its password is initially random.
                Feel free to edit the account and change both the name
                and the password.", -> callback newname

## Exporting

The module then exports a single instance of the `AccountsTable` class.

    module.exports = new AccountsTable
