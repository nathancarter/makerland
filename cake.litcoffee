
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
        build.enqueue 'compile'

## Requirements

Verify that `npm install` has been run in this folder, then import other
modules we'll need later (which were installed by npm install).

    build.verifyPackagesInstalled()
    fs = require 'fs'
    exec = require( 'child_process' ).exec

## Constants

These constants define how the functions below perform.

    p = require 'path'
    submodules = { }

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
        do recur = ->
            if ( next = toBuild.shift() )?
                build.compile next, recur
            else
                done()

## The `submodules` build process

Although there are currently no submodules, this task is ready in the
event that there will be more later.  It enters each of their subfolders and
runs any necessary build process on those submodules.

    build.asyncTask 'submodules', 'Build any git submodule projects',
    ( done ) ->
        commands = for own submodule, command of submodules
            description : "Running #{submodule} build process...".green
            command : "cd #{submodule} && #{command} && cd .."
        build.runShellCommands commands, done
