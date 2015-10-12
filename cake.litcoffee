
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

Finally, it prints a message to let the user know what they probably want to
do next to actually build the electron app.

            console.log '\n ** Electron app is prepared for building. **
    \nnpm run electron           = run electron app without building
    \nnpm run electron-unbuild   = run this before running the following
    \nnpm run electron-rebuild   = after installing a new module, use this
    \n                             to ensure that its binary version gets
    \n                             built portably into the electron app (?)
    \nnpm run electron-icon      = build electron.iconset -> electron.icns
    \nnpm run electron-package   = build electron app -> Makerland-*-*/'
            done()
