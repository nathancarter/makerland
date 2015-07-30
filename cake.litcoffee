
# Build process definitions

This file defines the build processes in this repository. It is imported by
the `Cakefile` in this repository, the source code of which is kept to a
one-liner, so that most of the repository can be written in [the literate
variant of CoffeeScript]( http://coffeescript.org/#literate).

We keep a set of build utilities in a separate module, which we now load.

    build = require './buildutils'

## Easy way to build all

If you want to build and test evertything, just run `cake all`. It simply
invokes all the other tasks, defined below.

    build.task 'all', 'All the other tasks together', ->
        build.enqueue 'compile', 'electron'

## Requirements

Verify that `npm install` has been run in this folder, then import other
modules we'll need later (which were installed by npm install).

    build.verifyPackagesInstalled()
    fs = require 'fs'
    exec = require( 'child_process' ).exec
    p = require 'path'

## The `compile` build process

    build.asyncTask 'compile', 'Compile all .litcoffee to .js', ( done ) ->

Concatenate all client-side `.litcoffee` source files into one.

        fs.unlinkSync './client/all.litcoffee'
        all = ( fs.readFileSync name for name in \
            build.dir './client', /\.litcoffee$/ )
        fs.writeFileSync './client/all.litcoffee', all.join( '\n\n' ),
            'utf8'

Run the compile process defined in the build utilities module.  This
compiles, minifies, and generates source maps.

        build.compile './client/all.litcoffee', -> done()

## The `electron` build process

    build.asyncTask 'electron', 'Compile all electron .litcoffee sources',
    ( done ) ->

The last thing it does is copy the entire client and server folders into the
electron app folder.  We define a function here to do that, and we use that
function below.

        toCopy = [ 'client', 'server', 'sampleuniverse', 'node_modules' ]
        copyEverything = ->
            if not ( next = toCopy.shift() )? then return done()
            ncp = require( 'ncp' ).ncp
            console.log "Copying #{next} folder into electron folder..."
            ncp "./#{next}", "./electron/#{next}", ( err ) ->
                if err
                    console.log "Error copying #{next} folder into electron
                        folder:", err
                    process.exit 1
                copyEverything()

The first thing it does is compile all the sources in the electron folder.
It then defers to the above function at the end of that process.

        toBuild = build.dir './electron', /\.litcoffee$/
        do recur = ->
            if ( next = toBuild.shift() )?
                build.compile next, recur
            else
                copyEverything()
