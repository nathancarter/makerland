
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
        gameview.width = jqgameview.width()
        gameview.height = jqgameview.height()
        context = gameview.getContext '2d'
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
        context.strokeStyle = '#000000'
        position = getPlayerPosition()
        xp = position[1] - Math.floor position[1]
        yp = position[2] - Math.floor position[2]
        xcenter = gameview.width/2 - cellSize*xp
        ycenter = gameview.height/2 - cellSize*yp
        x = xcenter - cellSize*Math.ceil xcells/2
        while x <= gameview.width
            line x, 0, x, gameview.height
            x += cellSize
        y = ycenter - cellSize*Math.ceil ycells/2
        while y <= gameview.height
            line 0, y, gameview.width, y
            y += cellSize

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
