
## Player Accounts Table

This module implements a game database table for storing player accounts.

    { Table } = require './table'
    hash = require 'password-hash'

It does so by subclassing the main Table class and adding account-specific
functionality.  It ensures that an admin account exists in the table.

    class AccountsTable extends Table

        constructor : () ->
            super 'accounts'
            if not @exists 'admin' then @createAccount 'admin', 'admin'

If the password is what's being set, hash it first.

        set : ( entryName, A, B ) =>
            if A is 'password' then B = hash.generate B
            super entryName, A, B

This method allows checking to see if a username-password pair is valid.
It should return false if the username doesn't exist, because the hashed
password fetched from the database will be undefined.

        validLoginPair : ( username, password ) =>
            hashedPassword = @get username, 'password'
            if not hashedPassword? then return no
            hash.verify password, hashedPassword

This method creates a new player account.  It throws an error if the account
already exists.

        create : ( username, password ) =>
            throw 'Account already exists: ' + username if @exists username
            @set username, { }
            @set username, 'password', password

The module then exports a single instance of the `AccountsTable` class.

    module.exports = new AccountsTable()
