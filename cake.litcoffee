
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
          \n1. Building and running the command-line app
          \n   The first line gets package binaries correct for the CLI.
          \n   Omit it if you did it more recently than electron-rebuild.
          \n     $ npm run electron-unbuild
          \n     $ cake compile
          \n     $ npm start [-- --root <universe folder>]
          \n   I usually write scripts to handle the final line (run).
          \n
          \n2. Building and running the electron app
          \n   The first line gets package binaries correct for the app.
          \n   Omit it if you did it more recently than electron-unbuild.
          \n     $ npm run electron-rebuild
          \n     $ cake electron
          \n     $ npm run electron
          \n
          \n3. Packaging the electron app for distribution
          \n   (Once you\'ve done the build step, 2., above.)
          \n   The DMG will be placed in an Makerland-*-*/ folder.
          \n     $ npm run electron-package
          \n     $ npm run electron-icon       # Only if you changed icons
          \n     $ npm run electron-unbuild    # So that appdmg will run
          \n     $ npm run electron-dmg
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
        backedUpNodeModules = no
        prunedNodeModules = no
        toBuild = build.dir './electron', /\.litcoffee$/
        toCopy = [ 'client', 'server', 'sampleuniverse', 'node_modules' ]
        tar = require 'tar-fs'
        do recur = ->

If we have not yet backed up `node_modules`, do that first.

            rimraf = require 'rimraf'
            if not backedUpNodeModules
                console.log "Removing ./electron/node_modules"
                rimraf 'electron/node_modules', ( err ) ->
                    throw err if err
                    console.log "Backing up ./node_modules to ./nmbackup"
                    reader = tar.pack "./node_modules"
                    reader.on 'end', ->
                        console.log "Backed up node_modules."
                        backedUpNodeModules = yes
                        recur()
                    reader.pipe tar.extract "./nmbackup"
                return

If we have not yet pruned `node_modules`, do that now.

            if not prunedNodeModules
                console.log 'Pruning node_modules for production'
                exec 'npm prune --production', { cwd : '.' },
                ( err, stdout, stderr ) ->
                    if stdout + stderr then console.log stdout + stderr.red
                    throw err if err
                    prunedNodeModules = yes
                    recur()
                return

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

Now restore `node_modules` from the backup.

            console.log 'Removing the node_modules used in the packaging'
            rimraf './node_modules', ( err ) ->
                throw err if err
                console.log 'Moving node_modules backup back into place'
                exec 'mv nmbackup node_modules', { cwd : '.' },
                ( err, stdout, stderr ) ->
                    if stdout + stderr then console.log stdout + stderr.red
                    throw err if err
                    done()
