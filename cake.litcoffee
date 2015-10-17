
# Build process definitions

This file defines the build processes in this repository. It is imported by
the `Cakefile` in this repository, the source code of which is kept to a
one-liner, so that most of the repository can be written in [the literate
variant of CoffeeScript]( http://coffeescript.org/#literate).

We keep a set of build utilities in a separate module, which we now load.

    build = require './buildutils'

## Help!

The build process is complicated.  This explains it.

    build.task 'help', 'Print an explanation of the build process(es).', ->
        console.log '
          \nCommon build workflows:
          \n-----------------------
          \n
          \n1. Building the command-line app
          \n   The first line gets package binaries correct for the CLI.
          \n   Omit it if you did it more recently than electron-rebuild.
          \n     $ npm run electron-unbuild
          \n     $ cake compile
          \n
          \n2. Running the command-line app
          \n   This assumes you have recently built the CLI (1., above).
          \n   I usually write scripts to do this, but it goes like so:
          \n     $ npm start [-- --root <universe folder>]
          \n
          \n3. Building the electron app
          \n   The first line gets package binaries correct for the app.
          \n   Omit it if you did it more recently than electron-unbuild.
          \n     $ npm run electron-rebuild
          \n     $ cake electron
          \n
          \n4. Running the electron app
          \n   This assumes you have recently built the app (3., above).
          \n     $ npm run electron
          \n
          \nOther build workflows:
          \n----------------------
          \n
          \n1. Packaging the electron app for distribution
          \n   This assumes you have recently built the app (3., above).
          \n   Packages created get placed in Makerland-*-*/ folders.
          \n     $ npm run electron-package
          \n
          \n2. Rebuild electron.icns from electron.iconset
          \n   Only needed if you change a file in electron.iconset.
          \n     $ npm run electron-icon
          \n'

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
        toBuild = build.dir './electron', /\.litcoffee$/
        toCopy = [ 'client', 'server', 'sampleuniverse', 'node_modules' ]
        tar = require 'tar-fs'
        do recur = ->

If there are things to build, do those first.

            if ( next = toBuild.shift() )?
                return build.compile next, recur

If there are folders to copy, do those next.

            if ( next = toCopy.shift() )?
                console.log "Copying ./#{next} to ./electron/#{next}..."
                reader = tar.pack "./#{next}"
                reader.on 'end', ->
                    console.log "Copied #{next}."
                    recur()
                reader.pipe tar.extract "./electron/#{next}"
                return
            done()
