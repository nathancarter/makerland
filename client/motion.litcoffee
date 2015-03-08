
# Player Location and Motion

## For This Player

The player's location is a triple (plane,x,y), where plane is a nonnegative
integer and x and y are floating point values.  It is always initialized to
(0,0,0).

    playerPosition = [ 0, 0, 0 ]

The following functions read and write the position.  Whenever the player
moves, we tell the server its new position, together with a maximum vision
distance (computed as 50% more than it really needs to be, to help with
caching blocks in advance).

    getPlayerPosition = -> playerPosition.slice()
    setPlayerPosition = ( triple ) -> playerPosition = triple
    movePlayer = ( dx, dy ) ->
        playerPosition = [
            playerPosition[0]
            playerPosition[1] + dx
            playerPosition[2] + dy
        ]
        socket.emit 'player position',
            position : playerPosition
            visionDistance : 1.5 * maximumVisionDistance()

The vision distance is computed in both the x and y directions, and the
maximum of the two is reported.  We divide by the cell size to convert from
screen units (pixels) to game map units (cells).

    maximumVisionDistance = ->
        cellSize = window.gameSettings.cellSizeInPixels
        distanceX = gameview.width / 2 / cellSize
        distanceY = gameview.height / 2 / cellSize
        if distanceX > distanceY then distanceX else distanceY

## For Moving Things Nearby

When things move nearby, the server tells us, using this mode of
communication.

    nearbyObjects = { }
    getNearbyObjects = -> nearbyObjects
    socket.on 'movement nearby', ( data ) ->
        key = switch data.type
            when 'player' then key = data.name
            else null # can't handle any other type yet
        if not key then return
        if data.position
            nearbyObjects[key] = data
        else
            delete nearbyObjects[key]
