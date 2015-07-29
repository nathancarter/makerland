
# Script run on universe creation page of Electron app

    ipc = require 'ipc'

This is thrown together now and mostly experimental.  It doesn't do much,
and is poorly documented.  Try back later.

Add event handlers to the "Create" and "Cancel" buttons.

    $ ->
        ( $ '#create-button' ).on 'click', ->
            try
                wake = JSON.parse ( $ '#inputWake' ).val()
            catch e
                wake = [ 0, 0, 0 ]
            if wake not instanceof Array or \
               wake.length isnt 3 or \
               typeof wake[0] isnt 'number' or \
               typeof wake[1] isnt 'number' or \
               typeof wake[2] isnt 'number'
                wake = [ 0, 0, 0 ]
            data =
                name : ( $ '#inputName' ).val() or 'My Cool Universe'
                privateGame : ( $ '#inputPrivate' ).val() is 'private'
                gameTitle : ( $ '#inputTitle' ).val() or \
                    '<h3>Log in or sign up:</h3>'
                gameTitleImage :
                    document.getElementById( 'chosen-file-name' ).innerHTML
                timePlayersStayDeadInSeconds :
                    parseInt ( $ '#inputDead' ).val() or 60
                cellSizeInPixels : parseInt ( $ '#inputCell' ).val() or 80
                mapBlockSizeInCells :
                    parseInt ( $ '#inputBlock' ).val() or 8
                movableItemLifespanInSeconds :
                    parseInt ( $ '#inputItem' ).val() or 600
                creatureLifespanInSeconds :
                    parseInt ( $ '#inputCreature' ).val() or 600
                locationPlayersAwakeAfterDeath : wake
            if data.timePlayersStayDeadInSeconds < 1
                data.timePlayersStayDeadInSeconds = 1
            if data.cellSizeInPixels < 10
                data.cellSizeInPixels = 10
            if data.mapBlockSizeInCells < 1
                data.mapBlockSizeInCells = 1
            if data.movableItemLifespanInSeconds < 10
                data.movableItemLifespanInSeconds = 10
            if data.creatureLifespanInSeconds < 10
                data.creatureLifespanInSeconds = 10
            ipc.send 'create new universe', data
            window.location.href = 'index.html'
        ( $ '#cancel-button' ).on 'click', ->
            window.location.href = 'index.html'
        ( $ '#choose-file-button' ).on 'click', ->
            ipc.send 'choose universe title image'

The main window will tell us if the user picks a title page image file.

    ipc.on 'file chosen', ( filename ) ->
        document.getElementById( 'chosen-file-name' ).innerHTML =
            "#{filename}".replace( /&/g, '&amp;' ).replace( /</g, '&lt;' )
