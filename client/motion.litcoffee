
# Player Location and Motion

## For This Player

The player's location is a triple (plane,x,y), where plane is a nonnegative
integer and x and y are floating point values.  It is always initialized to
(0,0,0).

    playerPosition = [ 0, 0, 0 ]
    playerMotionDirection = 0

The following functions read and write the position.  Whenever the player
moves, we tell the server its new position, together with a maximum vision
distance (computed as 50% more than it really needs to be, to help with
caching blocks in advance).

    getPlayerPosition = -> playerPosition.slice()
    setPlayerPosition = ( triple ) -> playerPosition = triple
    getPlayerMotionDirection = -> playerMotionDirection
    sendPositionToServer = ->
        socket.emit 'player position',
            position : playerPosition
            visionDistance : 1.5 * maximumVisionDistance()
    validPosition = ( position ) ->
        if not position then return no
        N = window.gameSettings.mapBlockSizeInCells
        if not N then return yes
        blockx = ( N * Math.floor position[1] / N ) | 0
        blocky = ( N * Math.floor position[2] / N ) | 0
        blockName = "#{position[0]},#{blockx},#{blocky}"
        blockData = window.visibleBlocksCache[blockName]?.cells
        if not blockData then return yes
        x = ( position[1] - blockx ) | 0
        y = ( position[2] - blocky ) | 0
        if x >= N then x = N - 1 # prevent float rounding inaccuracies
        if y >= N then y = N - 1 # prevent float rounding inaccuracies
        celltype = lookupCellType blockData[x][y]
        celltype['who can walk on it'] isnt 'none'
    movePlayer = ( dx, dy ) ->
        if not validPosition playerPosition
            setPlayerPosition [ 0, 0, 0 ]
            sendPositionToServer()
            return
        newPosition = playerPosition.slice()
        newPosition[1] += dx
        newPosition[2] += dy
        if not validPosition newPosition
            setWhereIWantToGo null
            return
        playerPosition = newPosition
        playerMotionDirection =
            if dx > 0
                1
            else if dx is 0
                if dy is 0 then 0 else playerMotionDirection or 1
            else
                -1
        if dx or dy then sendPositionToServer()

The server can also tell us the player position, and we must always trust
that, not our own records, because the server is the authoritative record of
the entire game.  (We wouldn't want to show the player an untrue
representation of the game world, or it could be dangerous for his/her
character.)

    socket.on 'player position', ( data ) ->
        setPlayerPosition data
        sendPositionToServer()
        setWhereIWantToGo null

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
            if nearbyObjects[key]?.position[0] is data.position[0]
                dx = data.position[1] - nearbyObjects[key].position[1]
                dy = data.position[2] - nearbyObjects[key].position[2]
                data.motionDirection =
                    if dx > 0
                        1
                    else if dx is 0
                        if dy is 0 then 0 else \
                            nearbyObjects[key].motionDirection or 1
                    else
                        -1
            else
                data.motionDirection = 0
            nearbyObjects[key] = data
            setTimeout ( do ( key, data ) -> ->
                if "#{nearbyObjects[key].position}" is "#{data.position}"
                    nearbyObjects[key].motionDirection = 0
            ), 100
        else
            delete nearbyObjects[key]

## Tracking Visible Map Blocks

When the set of blocks I can see changes, the game notifies me with a socket
message of the following form.

    window.visibleBlocksCache = { }
    socket.on 'visible blocks', ( data ) ->
        window.visibleBlocksCache = data
