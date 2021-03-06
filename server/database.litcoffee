
# Game Database Module

This module collects together in one place all database tables in the game.
Thus clients can just import this module and get all the rest for free.

    module.exports.tables = tables = [
        'accounts', 'celltypes', 'blocks', 'landscapeitems', 'behaviors',
        'logs', 'animations', 'sounds', 'movableitems', 'creatures',
        'abilities'
    ]

Also, clients can request files from the database.  So we have a function
for testing whether a URL points to a file in the database or not, and if it
does, then parsing out its pieces into table name, entry name, and key.
This function returns an object with those three key-value pairs, or null if
the given path is not a database URL.

    module.exports.parseDatabaseURL = ( path ) ->
        if /^\/db\/[^/]+\/[^/]+\/[^\/]+$/.test path
            [ table, entry, key ] = path.split( require( 'path' ).sep )[2..]
            table : table
            entry : entry
            key : key
        else
            null

We also provide the inverse function.

    module.exports.createDatabaseURL = ( table, entry, key ) ->
        "/db/#{table}/#{entry}/#{key}?#{encodeURIComponent new Date}"

The last thing this module does is install all the tables.  It does so last,
because then the above functions will be defined, which some of those tables
need in their initialization routines.

    for table in tables
        module.exports[table] = require "./#{table}"
