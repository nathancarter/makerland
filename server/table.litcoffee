
# Database Table Module

This module provides the abstract functionality common to all tables in the
game database.

We must know where the database is stored, which is a setting that we look
up.  We then ensure that the folder exists, or bomb with an error if we
cannot create it.

    path = require 'path'
    dbroot = ( require './settings' ).getPath 'gameDatabaseRoot'
    fs = require 'fs'
    try
        fs.mkdirSync dbroot
    catch e
        throw e if e.code isnt 'EEXIST'

## Table Class

Here we implement functionality common to all tables, so that table modules
can descend from this class.

    module.exports.Table = class Table

### Constructor

        constructor : ( @tableName ) ->
            module.exports[tableName] = this
            try
                fs.mkdirSync path.resolve dbroot, tableName
            catch e
                throw e if e.code isnt 'EEXIST'
            @defaults = { }

### Entries as Files

The `filename` function maps names of entries in the table to full paths in
the filesystem in which the entry should be stored.

        filename : ( entryName ) =>
            path.resolve dbroot, @tableName, "#{entryName}.json"

This function checks whether an entry exists in the table.

        exists : ( entryName ) =>
            try
                fs.lstatSync( @filename entryName ).isFile()
            catch e
                no

This function lists all entries in the table by name.  Its default
implementation just finds all filenames in the table's folder that have the
JSON format.  Subclasses may override with more specific implementations,
of course.

        entries : =>
            ( f[...-5] for f in \
                fs.readdirSync path.resolve dbroot, @tableName \
                when f[-5..] is '.json' )

### Reading and Writing

Set the default value for a given key.  This will prevail for all entries
that do not have that key.

        setDefault : ( key, value ) => @defaults[key] = value

Fetch the JSON object for a given entry in the table, or a specific value
from that entry's key-value pairs.

        get : ( entryName, key ) =>
            try
                entry = JSON.parse fs.readFileSync @filename entryName
                if not key? then entry else entry[key] or @defaults[key]
            catch e
                undefined

The following function can set the entire JSON object for an entry, if the
`set(entryName,A)` form is used, or just one key-value pair in the JSON, if
the `set(entryName,A,B)` form is used.

        set : ( entryName, A, B ) =>
            if B?
                current = @get entryName
                current[A] = B
                A = current
            fs.writeFileSync ( @filename entryName ), JSON.stringify A

The following are just convenience functions that use a field with the
special name "__authors" (unlikely to collide with any actual database
field name).  The authors list stored in these fields is used to determine
read and write permissions for tables that choose to use it.

        setAuthors : ( entryName, authorsList ) =>
            @set entryName, '__authors', authorsList
        getAuthors : ( entryName ) => @get entryName, '__authors'

For large values it doesn't make sense to store them in a JSON file with
other, smaller data, because it will make getting small data from the
database inefficient if a giant file must be read each time.  Thus we
provide the following two routines that read and write keys with large
values, by using files that sit in the filesystem next to the entry's JSON
file.

When setting a key-value pair in a certain entry, we must encode the key so
that it (a) has no dots in it (and thus serves as a single file extension)
and (b) is not equal to `json`, so that the file does not collide with the
entry's `.json` file.

        setFile : ( entryName, key, value ) =>
            key = key.replace( /_/g, '_und_' ).replace /\./g, '_dot_'
            filename = @filename( entryName ).replace /json$/, key
            fs.writeFileSync filename, value

When getting a key-value pair for a certain entry, we use the same scheme
for encoding keys used in `@setFile`.  We return undefined if the file does
not exist.

        getFile : ( entryName, key ) =>
            key = key.replace( /_/g, '_und_' ).replace /\./g, '_dot_'
            filename = @filename( entryName ).replace /json$/, key
            try
                fs.readFileSync filename
            catch e
                if e.code is 'ENOENT'
                    undefined
                else
                    throw e

### Maker Browsing and Editing

This function determines how an entry in the database will be displayed in
HTML format.  The default is just the entry's name, but subclasses can make
this more specific to be more user-friendly.

        show : ( entry ) -> "<p>#{entry}</p>"

These functions determine whether a maker can edit or remove a given entry
from the table, or add new entries.  The defaults check to see if the
player's name is on the authors list for an entry, but subclasses can
override one or more to implement their specific permission scheme.  Note
that if the table does not use authors lists for entries, then these
defaults are simply the same as saying no to every request for edit/remove
permissions.

        canEdit : ( player, entry ) ->
            authors = @getAuthors entry
            authors instanceof Array and player.name in authors
        canRemove : ( player, entry ) -> no
        canAdd : ( player ) -> no

The following convenience function can be called by implementations of the
`remove` method in subclasses.  It attempts to remove the entry as a file on
the filesystem, and returns a string describing success or failure.

        tryToRemove : ( entry ) =>
            try
                fs.unlinkSync @filename entry
                "Success.  Entry #{entry} removed."
            catch e
                "Error.  Could not remove entry #{entry}.  #{e}"
