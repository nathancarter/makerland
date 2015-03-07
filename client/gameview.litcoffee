
# Drawing the Game View

Set up redrawing of the canvas about 30 times per second.

    setInterval ( -> redrawCanvas() ), 33

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

Next, draw the game map.

        drawGameMap context

Next, draw the player's avatar.

        drawPlayerAvatar context

Last, draw the player's status as a HUD.

        drawPlayerStatus context

The following function draws the game map.  For now, this just makes a grid.

    drawGameMap = ( context ) ->
        context.strokeStyle = '#000000'
        x = gameview.width/2
        while x <= gameview.width
            context.beginPath()
            context.moveTo x, 0
            context.lineTo x, gameview.height
            context.moveTo gameview.width-x, 0
            context.lineTo gameview.width-x, gameview.height
            context.stroke()
            x += 100
        y = gameview.height/2
        while y <= gameview.height
            context.beginPath()
            context.moveTo 0, y
            context.lineTo gameview.width, y
            context.moveTo 0, gameview.height-y
            context.lineTo gameview.width, gameview.height-y
            context.stroke()
            y += 100

THe following function draws the player's avatar.  For now, this is just a
rectangle.

    drawPlayerAvatar = ( context ) ->
        context.fillStyle = '#ff0000'
        context.fillRect gameview.width/2-10, gameview.height/2-10, 20, 20

The following function draws the player's status as a HUD.  For now, this is
just the player's name (after login only).

    drawPlayerStatus = ( context ) ->
        context.font = '20px serif'
        context.fillStyle = '#000000'
        name = currentStatus.name[0].toUpperCase() + currentStatus.name[1..]
        size = context.measureText name
        context.fillText name, gameview.width - size.width - 40, 30
