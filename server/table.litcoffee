
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

The constructor installs the table in the module's `exports` object, then
ensures that the folder for storing the table on disk exists or can be
created.  After that it initializes the defaults and cache data structures
to empty values.

        constructor : ( @tableName, @humanReadableName ) ->
            @humanReadableName ?=
                @tableName[0].toUpperCase() + @tableName[1..]
            module.exports[tableName] = this
            try
                fs.mkdirSync path.resolve dbroot, tableName
            catch e
                throw e if e.code isnt 'EEXIST'
            @defaults = { }
            @cache =
                entries : { }
                sizes : { }
                order : [ ]
                totalSize : 0

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

### Caching

The get and set routines below will use a cache, if it is available.  This
prevents unnecessary reading from disk for recently-accessed table entries.

Looking something up in the cache returns the cached value if it exists, and
null otherwise.  If the cached value is used, then it gets promoted to the
top of the list of cached values, meaning that it was most recently
accessed, and thus last in line to be decached.

        cacheLookup : ( entryName ) =>
            if @cache.entries.hasOwnProperty entryName
                @cache.order.splice @cache.order.indexOf( entryName ), 1
                @cache.order.unshift entryName
                @cache.entries[entryName]
            else
                null

Putting something into the cache is done when a write operation takes place
on the table, and a new value for an entry is about to be saved to disk.
The same value must also be placed in the cache, so that the cache continues
to reflect the state of the table on disk.  Writing to an entry also moves
it to the most-recently-accessed spot in the cache order.

We start this function by removing the old version from the cache, then
proceed to re-cache the new version.  Putting something into the cache
always triggers a call to `clearCache`, so that the cache never exceeds its
maximum size.  Note that if this entry alone would be larger than the size
of the cache, we simply don't bother caching it.

        putIntoCache : ( entryName, entry, entrySize ) =>
            @removeFromCache entryName
            if entrySize <= @maxCacheSize
                @cache.order.unshift entryName
                @cache.entries[entryName] = entry
                @cache.sizes[entryName] = entrySize
                @cache.totalSize += entrySize
                @clearCache()

Removing something from the cache deletes it from memory, but of course not
from disk.  The cache simply becomes smaller.  But the entry will re-appear
in the cache if `cacheLookup` is called again on it later.

        removeFromCache : ( entryName ) =>
            if @cache.entries.hasOwnProperty entryName
                @cache.totalSize -= @cache.sizes[entryName]
                @cache.order.splice @cache.order.indexOf( entryName ), 1
                delete @cache.sizes[entryName]
                delete @cache.entries[entryName]

Clearing the cache means calling `removeFromCache` repeatedly until the
total cache size is below a certain level.  Subclasses can set this level
by simply setting their `@maxCacheSize` member, which has the following
default.

        maxCacheSize : 25000
        clearCache : =>
            maxSize = @maxCacheSize
            while @cache.order.length and @cache.totalSize > maxSize
                @removeFromCache @cache.order[@cache.order.length-1]

### Reading and Writing

Set the default value for a given key.  This will prevail for all entries
that do not have that key.  If you fetch an entire entry, you can also fill
in default values for all its keys with the `installDefault` function.

        setDefault : ( key, value ) => @defaults[key] = value
        installDefaults : ( entry ) =>
            entry[key] ?= value for own key, value of @defaults
        getWithDefaults : ( entryName ) =>
            result = @get entryName
            @installDefaults result if result
            result

Fetch the JSON object for a given entry in the table, or a specific value
from that entry's key-value pairs.

        get : ( entryName, key ) =>
            try
                if not entry = @cacheLookup entryName
                    entryJSON = fs.readFileSync @filename entryName
                    entry = JSON.parse entryJSON
                    @putIntoCache entryName, entry, entryJSON.length
                if not key? then entry else entry[key] ? @defaults[key]
            catch e
                undefined

The following function can set the entire JSON object for an entry, if the
`set(entryName,A)` form is used, or just one key-value pair in the JSON, if
the `set(entryName,A,B)` form is used.

        set : ( entryName, A, B ) =>
            if B?
                current = @get( entryName ) or { }
                current[A] = B
                A = current
            entryJSON = JSON.stringify A
            if not @noCacheOnSetFlag
                @putIntoCache entryName, A, entryJSON.length
            @noCacheOnSetFlag = no
            fs.writeFileSync ( @filename entryName ), entryJSON

Some tables do not want the cache touched just because an entry was set in
the table; for those, we provide the following function, which disables that
feature just for the immediate next call to `set()`, as you can see in the
implementation of `set`, above.

        doNotCacheOnSet : => @noCacheOnSetFlag = yes

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

We can also ask how large a certain file-type value is on disk.  A size of
-1 means that there was an error attempting to read the file, e.g., there is
no file-type value for that entry and key.

        fileSize : ( entryName, key ) =>
            key = key.replace( /_/g, '_und_' ).replace /\./g, '_dot_'
            filename = @filename( entryName ).replace /json$/, key
            try
                fs.statSync( filename ).size
            catch e
                -1

And since we can get and set file values on entries, it's good to also be
able to get a list of such entries, and to remove one.

        removeFile : ( entryName, key ) =>
            key = key.replace( /_/g, '_und_' ).replace /\./g, '_dot_'
            try fs.unlinkSync @filename( entryName ).replace /json$/, key
        allFileKeys : ( entryName ) =>
            encodedKeys = ( f[entryName.length+1..] for f in \
                fs.readdirSync path.resolve dbroot, @tableName \
                when f[..entryName.length] is "#{entryName}." and \
                     /^[^.]+$/.test( f[entryName.length+1..] ) and \
                     f[entryName.length+1..] isnt 'json' )
            for key in encodedKeys
                key.replace( /_dot_/g, '.' ).replace( /_und_/g, '_' )

### Maker Browsing and Editing

This function determines how an entry in the database will be displayed in
HTML format.  The default is just the entry's name, but subclasses can make
this more specific to be more user-friendly.

        show : ( entry ) -> "<p>#{entry}</p>"

The `show` functions of subclasses may like to fetch an icon from the
database, if the item has one.  Other situations may use this as well, such
as the player's inventory command.  We provide the following tools for doing
so conveniently.

        smallIcon : ( entry, keyName = 'icon', size = 100 ) =>
            db = require './database'
            "<img width=#{size}
                  src='#{db.createDatabaseURL @tableName, entry, keyName}'
                  onerror='this.style.display=\"none\"'/>"
        normalIcon : ( entry, keyName = 'icon' ) =>
            db = require './database'
            "<img src='#{db.createDatabaseURL @tableName, entry, keyName}'
                  onerror='this.style.display=\"none\"'/>"

These functions determine whether a maker can edit or remove a given entry
from the table, or add new entries.  The defaults check to see if the
player's name is on the authors list for an entry, but subclasses can
override one or more to implement their specific permission scheme.  Note
that if the table does not use authors lists for entries, then these
defaults are simply the same as saying no to every request for edit/remove
permissions.

        canEdit : ( player, entry ) =>
            authors = @getAuthors entry
            authors instanceof Array and player.name in authors
        canRemove : ( player, entry ) -> no
        canAdd : ( player ) -> no

Subclasses that implement an `add` method should have it take two
parameters; the first is the player object doing the add and the second is
the UI callback function for when the add is done.  (The `add` routine may
need to ask the player some questions.)  It should call that callback with
the new entry's name as parameter.

The following convenience function can be called by implementations of the
`remove` method in subclasses.  It attempts to remove the entry as a file on
the filesystem, and returns a string describing success or failure.

        tryToRemove : ( entry ) =>
            try
                for key in @allFileKeys entry
                    key = key.replace( /_/g, '_und_' ) \
                             .replace( /\./g, '_dot_' )
                    filename = @filename( entry ).replace /json$/, key
                    fs.unlinkSync filename
                fs.unlinkSync @filename entry
                "Success.  Entry #{entry} removed."
            catch e
                "Error.  Could not remove entry #{entry}.  #{e}"

The following convenience function attempts to duplicate an entry in the
database.  If `canAdd` fails for the given player, it does nothing.
Otherwise, it calls `add()` to create a new entry, then moves over all
key-value pairs (except the authors list) from the old entry to the new.
(The authors list will be set by the call to `add`.)  File-type values are
also duplicated.

        duplicate : ( player, entry, uiCallback ) =>
            if not @canAdd player then return uiCallback()
            @add player, ( newentry ) =>
                for own key, value of @get entry
                    if key isnt '__authors'
                        valueCopy = value
                        if valueCopy instanceof Object
                            valueCopy = JSON.parse JSON.stringify valueCopy
                        @set newentry, key, valueCopy
                for key in @allFileKeys entry
                    @setFile newentry, key, @getFile entry, key
                uiCallback()

The following function creates a single UI item that shows a particular
entry from a given database table, and allows you to click "Change" to
select a different one.  If you click "Change" it presents an entire other
UI pane, lets you choose the new entry, then returns to the UI given as the
`uiCallback` parameter.  The appearance of the entry is as the `show()`
function from its table gives, plus a hidden input field that maps the
given name for this UI element to the name of the selected table entry.

Example JavaScript usage:
```js
// you must declare it up here so that it's one instance across all calls
// of the showMyUI() function below
uiItem = myTable.entryChooser( playerObject, 'put key name here',
    'optional initial entry name here' );
// then name the function for showing the UI, so that you can pass it as a
// UI callback when needed
function showMyUI () {
    player.showUI( [
        // some UI elements here...
        uiItem( showMyUI ), // this provides the callback when done
        // more UI elements here...
    ] );
}
// now show the UI
showMyUI();
```

And now the actual implementation.

        entryChooser : ( player, keyname, initialChoice ) =>
            choice = initialChoice
            ( uiCallback ) => [
                type : 'text'
                value : "<p>#{keyname}:</p>
                         <input type='hidden' id='input_#{keyname}'
                                value='#{choice}'/>"
            ,
                type : 'text'
                value : if @exists choice then @show choice else '[none]'
            ,
                type : 'action'
                value : 'Change'
                action : =>
                    controls = for entry in @entries()
                        do ( entry ) => [
                            type : 'text'
                            value : @show entry
                        ,
                            type : 'action'
                            value : 'Choose'
                            action : => choice = entry ; uiCallback()
                        ]
                    controls.push
                        type : 'action'
                        value : 'Cancel'
                        cancel : yes
                        action : uiCallback
                    player.showUI controls
            ]
