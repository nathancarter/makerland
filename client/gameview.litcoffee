
# Game View

The game view is the left pane, in which the player sees the map and
interacts with the game.

## Drawing

Set up redrawing of the canvas about 30 times per second.

    frameRate = 33
    setInterval ( -> redrawCanvas() ), frameRate

This function declares how to draw the game view on the canvas.

    redrawCanvas = ->

First, clear the canvas.

        jqgameview = $ gameview
        if gameview.width isnt jqgameview.width()
            gameview.width = jqgameview.width()
        if gameview.height isnt jqgameview.height()
            gameview.height = jqgameview.height()
        context = gameview.getContext '2d'

If we're supposed to be showing a splash screen, just do that.  Otherwise,
clear the game view for other drawing.

        if currentStatus.splash
            drawSplashScreen currentStatus.splash
            return
        context.fillStyle = '#dddddd'
        context.fillRect 0, 0, gameview.width, gameview.height

If the player hasn't logged in, then don't show anything else.

        if not currentStatus.name? then return

Update the game state based on whatever keys the player has pressed.

        handleKeysPressed()

Next, draw the game map.

        drawGameMap context

Next, draw the player's avatar, together with the avatars of anything moving
nearby.

        drawPlayer context
        drawOtherPlayers context

Last, draw the player's status as a HUD.

        drawPlayerStatus context

In order to draw the cells in the game map, we need to cache their icons.
This datum and routine do so.

    gameMapCache = { }
    getCellTypeIcon = ( index ) ->
        if not gameMapCache.hasOwnProperty index
            gameMapCache[index] = new Image
            gameMapCache[index].src =
                "db/celltypes/#{index}/icon?#{encodeURIComponent new Date}"
        gameMapCache[index]
    socket.on 'icon changed', ( data ) ->
        delete gameMapCache[parseInt data]

The following function draws the game map.  For now, this just makes a grid
that moves as the player walks.  Later, it will have an actual map in it.

    drawGameMap = ( context ) ->
        cellSize = window.gameSettings.cellSizeInPixels
        if not cellSize then return
        line = ( x1, y1, x2, y2 ) ->
            context.beginPath()
            context.moveTo x1, y1
            context.lineTo x2, y2
            context.stroke()
        xcells = Math.ceil gameview.width/cellSize
        ycells = Math.ceil gameview.height/cellSize
        context.strokeStyle = context.fillStyle = '#000000'
        context.lineWidth = 1
        blockSize = window.gameSettings.mapBlockSizeInCells
        for own name, array of window.visibleBlocksCache
            [ plane, x, y ] = ( parseInt i for i in name.split ',' )
            for i in [0...blockSize]
                for j in [0...blockSize]
                    screen = mapCoordsToScreenCoords x+i, y+j
                    drawn = no
                    if array[i][j] > -1
                        image = getCellTypeIcon array[i][j]
                        if image.complete
                            try
                                context.drawImage image, screen.x, screen.y,
                                    cellSize, cellSize
                                drawn = yes
                    if not drawn
                        line screen.x, screen.y, screen.x, screen.y+cellSize
                        line screen.x, screen.y, screen.x+cellSize, screen.y
    mapCoordsToScreenCoords = ( x, y ) ->
        cellSize = window.gameSettings.cellSizeInPixels
        position = getPlayerPosition()
        x : gameview.width*0.5 + ( x - position[1] ) * cellSize
        y : gameview.height*0.5 + ( y - position[2] ) * cellSize
    screenCoordsToMapCoords = ( x, y ) ->
        cellSize = window.gameSettings.cellSizeInPixels
        position = getPlayerPosition()
        x : position[1] + ( x - gameview.width*0.5 ) / cellSize
        y : position[2] + ( y - gameview.height*0.5 ) / cellSize

The following function draws the player's avatar by calling a routine
defined in a separate file.

    drawPlayer = ( context ) ->
        name = currentStatus.name[0].toUpperCase() + currentStatus.name[1..]
        drawAvatar context, name, getPlayerPosition(),
            getPlayerMotionDirection(), currentStatus.appearance
    drawOtherPlayers = ( context ) ->
        for own key, value of getNearbyObjects()
            if value.type is 'player'
                key = key[0].toUpperCase() + key[1..]
                drawAvatar context, key, value.position,
                    value.motionDirection, value.appearance

The following function draws the player's status as a HUD.  For now, this is
just the player's name (after login only).

    drawPlayerStatus = ( context ) ->
        context.font = '20px serif'
        context.fillStyle = '#000000'
        name = currentStatus.name[0].toUpperCase() + currentStatus.name[1..]
        size = context.measureText name
        context.fillText name, gameview.width - size.width - 40, 30
        position = JSON.stringify getPlayerPosition()
        size = context.measureText position
        context.fillText position, gameview.width - size.width - 40, 60

## Interacting with the Game Map

First we track all keys pressed in the game view, so that several times per
second we can take game actions based on them.  This is mostly used for
motion, but not entirely.

    keysDown = { }
    keyCodes = left : 37, up : 38, right : 39, down : 40

The game view should ignore keyboard events if the focus is in an input box
or a button.

    shouldIgnoreKeyboardEvent = ->
        tagType = document.activeElement.tagName.toLowerCase()
        tagType in [ 'input', 'button' ]

Otherwise, it should record key down and up events so that we can handle
them periodically.

    document.body.onkeydown = ( event ) ->
        if shouldIgnoreKeyboardEvent() then return
        keysDown[event.keyCode] = yes
    document.body.onkeyup = ( event ) ->
        if shouldIgnoreKeyboardEvent() then return
        delete keysDown[event.keyCode]

Periodically respond to whichever keys are being held down.  This is called
by the view-redrawing event, so that the key rate and frame rate are in
sync.  Feel free to make computations herein depend on `frameRate`.

    handleKeysPressed = ->
        dx = dy = 0
        speed = 2 * frameRate/1000
        if keysDown[keyCodes.left] then dx -= speed
        if keysDown[keyCodes.right] then dx += speed
        if keysDown[keyCodes.up] then dy -= speed
        if keysDown[keyCodes.down] then dy += speed
        movePlayer dx, dy

## Splash Screen

At login time, the game shows a title screen called a "splash screen."  The
following function supports doing so.

    drawSplashScreen = ( imageURL ) ->
        image = new Image;
        image.onload = ->
            jqgameview = $ gameview
            gameview.width = jqgameview.width()
            gameview.height = jqgameview.height()
            context = gameview.getContext '2d'
            context.drawImage image, 0, 0, gameview.width, gameview.height
        image.src = imageURL
