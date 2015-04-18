
# Game View

The game view is the left pane, in which the player sees the map and
interacts with the game.

## Cell Type Cache

In order to be able to draw cells on the map, we need to know about them.
Thus we have a cache of information about them, and routines for accessing
it, and requesting its data from the server.  This includes the icon and
other data as well.

    cellTypeData = { }
    lookupCellType = ( index ) ->
        if not cellTypeData.hasOwnProperty index
            cellTypeData[index] = { }
            socket.emit 'get cell type data', index
        cellTypeData[index]
    socket.on 'cell type data', ( data ) ->
        cellTypeData[data.index] = data
    getCellTypeIcon = ( index ) ->
        key = "#{index} icon"
        if not cellTypeData.hasOwnProperty key
            cellTypeData[key] = new Image
            timestamp = encodeURIComponent new Date
            cellTypeData[key].src =
                "db/celltypes/#{index}/icon?#{timestamp}"
        cellTypeData[key]
    socket.on 'cell data changed', ( data ) ->
        delete cellTypeData[data]
        delete cellTypeData["#{data} icon"]

Now we create very similar functions for getting data on landscape items
from the server.

    landscapeItemData = { }
    lookupLandscapeItemType = ( index ) ->
        if not landscapeItemData.hasOwnProperty index
            landscapeItemData[index] = { }
            socket.emit 'get landscape item data', index
        landscapeItemData[index]
    socket.on 'landscape item data', ( data ) ->
        landscapeItemData[data.index] = data
    getLandscapeItemIcon = ( index ) ->
        key = "#{index} icon"
        if not landscapeItemData.hasOwnProperty key
            landscapeItemData[key] = new Image
            timestamp = encodeURIComponent new Date
            landscapeItemData[key].src =
                "db/landscapeitems/#{index}/icon?#{timestamp}"
        landscapeItemData[key]
    socket.on 'landscape item changed', ( data ) ->
        delete landscapeItemData[data]
        delete landscapeItemData["#{data} icon"]

And we also create very similar functions for getting data on movable items
from the server.

    movableItemData = { }
    lookupMovableItemType = ( index ) ->
        if not movableItemData.hasOwnProperty index
            movableItemData[index] = { }
            socket.emit 'get movable item data', index
        movableItemData[index]
    socket.on 'movable item data', ( data ) ->
        movableItemData[data.index] = data
    getMovableItemIcon = ( index ) ->
        key = "#{index} icon"
        if not movableItemData.hasOwnProperty key
            movableItemData[key] = new Image
            timestamp = encodeURIComponent new Date
            movableItemData[key].src =
                "db/movableitems/#{index}/icon?#{timestamp}"
        movableItemData[key]
    socket.on 'movable item changed', ( data ) ->
        delete movableItemData[data]
        delete movableItemData["#{data} icon"]

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

Next, draw the game map, then the layer of landscape items on top of it.
Landscape items include the player's avatar, together with any other avatars
of other players nearby.

        drawGameMap context
        drawLandscapeItems context

On top of all those things, draw any animations currently running.

        drawAnimations context

Last, draw the player's status as a HUD.

        drawPlayerStatus context

First, if the player is dead, we make everything fade away.

        if currentStatus.dead
            currentStatus.timeOfDeath ?= new Date
            howLongDead = ( new Date ) - currentStatus.timeOfDeath
            context.save();
            context.globalAlpha = Math.min 1, howLongDead/3000
            context.fillStyle = '#550000'
            context.fillRect 0, 0, gameview.width, gameview.height
            context.restore();

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
        blockSize = window.gameSettings.mapBlockSizeInCells
        for own name, data of window.visibleBlocksCache
            [ plane, x, y ] = ( parseInt i for i in name.split ',' )
            array = data.cells
            for i in [0...blockSize]
                for j in [0...blockSize]
                    screen = mapCoordsToScreenCoords x+i, y+j
                    drawn = no
                    cellType = array[i][j]
                    if cellType is -1
                        cellType = currentStatus.defaultCellType
                    if cellType > -1
                        index = cellType
                        ctdata = lookupCellType index
                        image = getCellTypeIcon index
                        if image.complete
                            try
                                context.drawImage image, screen.x, screen.y,
                                    cellSize, cellSize
                                drawn = yes
                    if not drawn
                        context.strokeStyle = context.fillStyle = '#999999'
                        context.lineWidth = 1
                        line screen.x, screen.y, screen.x, screen.y+cellSize
                        line screen.x, screen.y, screen.x+cellSize, screen.y
        for own name, data of window.visibleBlocksCache
            [ plane, x, y ] = ( parseInt i for i in name.split ',' )
            array = data.cells
            for i in [0...blockSize]
                for j in [0...blockSize]
                    screen = mapCoordsToScreenCoords x+i, y+j
                    cellType = array[i][j]
                    if cellType is -1
                        cellType = currentStatus.defaultCellType
                    if cellType > -1
                        index = cellType
                        ctdata = lookupCellType index
                        if ctdata and ctdata['border size'] > 0
                            context.strokeStyle = ctdata['border color']
                            context.lineWidth = ctdata['border size']
                            if getMapCell( plane, x+i-1, y+j ) isnt index
                                line screen.x, screen.y,
                                    screen.x, screen.y+cellSize
                            if getMapCell( plane, x+i+1, y+j ) isnt index
                                line screen.x+cellSize, screen.y,
                                    screen.x+cellSize, screen.y+cellSize
                            if getMapCell( plane, x+i, y+j-1 ) isnt index
                                line screen.x, screen.y,
                                    screen.x+cellSize, screen.y
                            if getMapCell( plane, x+i, y+j+1 ) isnt index
                                line screen.x, screen.y+cellSize,
                                    screen.x+cellSize, screen.y+cellSize
    getMapCell = ( plane, x, y ) ->
        N = window.gameSettings.mapBlockSizeInCells
        blkx = ( N * Math.floor x/N ) | 0
        blky = ( N * Math.floor y/N ) | 0
        blkname = "#{plane},#{blkx},#{blky}"
        cell = window.visibleBlocksCache[blkname]?.cells[x - blkx][y - blky]
        if cell is -1 then currentStatus.defaultCellType ? -1 else cell
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

A similar function draws the landscape items that sit in a layer on top of
the map.  It creates an objects called `orderedItems` that maps y
coordinates to arrays of objects that have that y coordinate.  Then it draws
items in increasing order of y coordinates, so that things that belong near
the front of the screen are drawn as if they are in front of things behind
them.

This function includes players' avatars among the landscape items, because
they are z-ordered in among them, so that players can, f.ex., hide behind a
tree.  It also includes movable items among the landscape items, for the
same reason.

    drawLandscapeItems = ( context ) ->
        orderedItems = { }
        add = ( item ) ->
            if not item.x or not item.y
                screencoords = mapCoordsToScreenCoords item.position[1],
                    item.position[2]
                item.x = screencoords.x
                item.y = screencoords.y
            if item.type is 'item'
                item.x -= item.width/2
                item.y -= item.height/2
            bottomy = switch item.type
                when 'player' then item.y
                when 'item' then item.y + item.height
                else undefined
            orderedItems[bottomy] ?= [ ]
            orderedItems[bottomy].push item
        cellSize = window.gameSettings.cellSizeInPixels
        if not cellSize then return
        blockSize = window.gameSettings.mapBlockSizeInCells
        for own name, data of window.visibleBlocksCache
            [ plane, x, y ] = ( parseInt i for i in name.split ',' )
            for item in data['landscape items'] ? [ ]
                [ itemx, itemy ] = item.position
                screenpos = mapCoordsToScreenCoords itemx+x, itemy+y
                if typeinfo = lookupLandscapeItemType item.type
                    image = getLandscapeItemIcon item.type
                    if image.complete
                        add
                            type : 'item'
                            image : image
                            x : screenpos.x
                            y : screenpos.y
                            width : cellSize*typeinfo.size
                            height : cellSize*typeinfo.size
            for item in data['movable items'] ? [ ]
                [ plane, itemx, itemy ] = item.location
                screenpos = mapCoordsToScreenCoords itemx, itemy
                if typeinfo = lookupMovableItemType item.index
                    image = getMovableItemIcon item.index
                    if image.complete
                        add
                            type : 'item'
                            image : image
                            x : screenpos.x
                            y : screenpos.y
                            width : image.width
                            height : image.height
        add
            type : 'player'
            name : currentStatus.name[0].toUpperCase() + \
                currentStatus.name[1..]
            position : getPlayerPosition()
            direction : getPlayerMotionDirection()
            appearance : currentStatus.appearance
        for own key, value of getNearbyObjects()
            if value.type is 'player'
                add
                    type : 'player'
                    name : key[0].toUpperCase() + key[1..]
                    position : value.position
                    direction : value.motionDirection
                    appearance : value.appearance
        keys = Object.keys orderedItems
        keys.sort ( a, b ) -> parseFloat( a ) - parseFloat( b )
        for key in keys
            for item in orderedItems[key]
                if item.type is 'item'
                    try
                        context.drawImage item.image, item.x, item.y,
                            item.width, item.height
                if item.type is 'player'
                    drawAvatar context, item.name, item.position,
                        item.direction, item.appearance

The following function draws the player's status as a HUD.  For now, this is
just the player's name (after login only).

    HUDZones = { }
    drawPlayerStatus = ( context ) ->
        if currentStatus.dead then return
        fontsize = 20
        context.font = "#{fontsize}px serif"
        context.fillStyle = '#000000'
        name = currentStatus.name[0].toUpperCase() + currentStatus.name[1..]
        size = context.measureText name
        context.fillText name, gameview.width - size.width - 40, 45
        if currentStatus.isMaker
            [ plane, x, y ] = getPlayerPosition()
            x = "#{x}".substring 0, "#{x|0}".length+3
            y = "#{y}".substring 0, "#{y|0}".length+3
            position = "#{plane},#{x},#{y}"
            size = context.measureText position
            context.fillText position, gameview.width - size.width - 40, 70
        pctHP = currentStatus.hitPoints / currentStatus.maximumHitPoints
        context.fillRect gameview.width - 142, 10, 102, 12
        hexpct = Math.floor pctHP * 30
        greenletter = '0123456789abcdefffffffffffffffff'[hexpct]
        redletter = 'fffffffffffffffffedcba9876543210'[hexpct]
        context.fillStyle =
            "##{redletter}#{redletter}#{greenletter}#{greenletter}00"
        context.fillRect gameview.width - 141, 11, 100*pctHP, 10
        i = 0 ; edge = 80 ; margin = 20
        HUDZones = { }
        for own command, icon of currentStatus.HUD
            icon = getCommandIcon icon
            if icon.complete
                context.fillStyle = '#eeeeee'
                left = margin+edge*i+margin*(i+1)
                top = gameview.height-edge-margin
                right = left + edge
                bottom = top + edge
                context.fillRect left, top, edge, edge
                context.strokeStyle = '#555555'
                context.beginPath()
                context.rect left, top, edge, edge
                context.stroke()
                HUDZones["#{left},#{top},#{right},#{bottom}"] = command
                context.fillStyle = '#000000'
                text = command[0].toUpperCase() + command[1..]
                size = context.measureText text
                context.fillText text,
                    margin+edge*i+margin*(i+1)+edge/2-size.width/2,
                    gameview.height-margin-10
                context.drawImage icon, margin+edge*i+margin*(i+1)+10,
                    gameview.height-edge-margin+10
                if currentStatus.shortcuts[command]
                    text = currentStatus.shortcuts[command].toUpperCase()
                    size = context.measureText text
                    context.fillText text,
                        margin+(edge+margin)*(i+1)-10-size.width,
                        gameview.height-margin-edge+10+fontsize
            i++

It uses the following routine, which caches command icons.

    commandIconCache = { }
    getCommandIcon = ( name ) ->
        if not commandIconCache.hasOwnProperty name
            commandIconCache[name] = new Image
            commandIconCache[name].src = "icons/#{name}"
        commandIconCache[name]

## Animations

The following function responds to a message from the server that lists all
animations that are currently running in a specific block, together with the
definitions of any that the client does not currently know about (or for
which its known definition is out-of-date).  It creates all the necessary
animation data for drawing the animation, then sticks it into a global
object of active animations that is used in each call to `redrawCanvas`,
indirectly, by the `drawAnimations` routine below.

    animationCache = { }
    activeAnimations = { }
    socket.on 'animations for block', ( message ) ->
        activeAnimations[message.block] = [ ]
        for animation in message.animations
            if animation.definition?
                animationCache[animation.type] = animation.definition
            if not code = animationCache[animation.type]?.code then continue
            for own paramName of animation.parameters
                code = "var #{paramName} = args.#{paramName};\n#{code}"
            code = "(function(t,args,view,memory){
                        view.save();\n
                        function POS ( name ) {
                            if ( name.toLowerCase() ==
                                 currentStatus.name.toLowerCase() )
                                return getPlayerPosition();
                            var all = getNearbyObjects();
                            return all.hasOwnProperty( name ) ?
                                all[name].position : null;
                        }
                        function XY ( position ) {
                            if ( !position ) return null;
                            var mypos = getPlayerPosition();
                            if ( !mypos ) return null;
                            return ( position[0] == mypos[0] ) ?
                                mapCoordsToScreenCoords(
                                    position[1], position[2] ) : null;
                        }
                        function X ( position ) {
                            var xy = XY( position ); return xy ? xy.x : NaN;
                        }
                        function Y ( position ) {
                            var xy = XY( position ); return xy ? xy.y : NaN;
                        }
                        var CELL =
                            #{window.gameSettings.cellSizeInPixels};\n
                        with ( view ) { #{code} }
                        view.restore();
                    })"
            try
                animationFunction = eval code
            catch e
                console.log "Could not create animation:", code, e
                return
            activeAnimations[message.block].push
                startTime : ( new Date ) - animation.elapsed
                function : animationFunction
                parameters : animation.parameters
                duration : animationCache[animation.type]?.duration ? 1
                definition : animationCache[animation.type]
                memory : { }

This routine is called by `redrawCanvas`, not only to draw all active
animations, but also to clear out those that have run their full course.

    drawAnimations = ( context ) ->
        if currentStatus.dead then return
        now = new Date
        for own block, animations of activeAnimations
            updatedList = [ ]
            for animation in animations
                elapsed = ( now - animation.startTime ) / 1000
                if animation.duration is 0
                    t = elapsed # 0-length animations go forever
                else
                    t = elapsed / animation.duration
                    if t >= 1 then continue # >0-length ones eventually end
                try
                    animation.function t, animation.parameters, context,
                        animation.memory
                    updatedList.push animation
                catch e
                    console.log "In animation #{animation.definition.name}
                        with t=#{t}: #{e.stack}"
            activeAnimations[block] = updatedList
        for own block, animations of activeAnimations
            if animations.length is 0 then delete activeAnimations[block]

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
        tagType in [ 'input', 'button', 'textarea', 'select' ]

Otherwise, it should record key down and up events so that we can handle
them periodically.

    ( $ document.body ).on 'keydown', ( event ) ->
        if shouldIgnoreKeyboardEvent() then return
        keysDown[event.keyCode] = yes
    ( $ document.body ).on 'keyup', ( event ) ->
        if shouldIgnoreKeyboardEvent() then return
        delete keysDown[event.keyCode]

Periodically respond to whichever keys are being held down.  This is called
by the view-redrawing event, so that the key rate and frame rate are in
sync.  Feel free to make computations herein depend on `frameRate`.

    handleKeysPressed = ->
        if currentStatus.dead then return
        dx = dy = 0
        speed = 2 * frameRate/1000
        if keysDown[keyCodes.left] or keysDown[keyCodes.right] or \
                keysDown[keyCodes.up] or keysDown[keyCodes.down]
            setWhereIWantToGo null
            if keysDown[keyCodes.left] then dx -= speed
            if keysDown[keyCodes.right] then dx += speed
            if keysDown[keyCodes.up] then dy -= speed
            if keysDown[keyCodes.down] then dy += speed
        else if destination = getWhereIWantToGo()
            [ plane, x, y ] = getPlayerPosition()
            if ( Math.abs( x - destination.x ) <= speed ) and \
                    ( Math.abs( y - destination.y ) <= speed )
                setWhereIWantToGo null
                return
            else
                if ( x < destination.x ) and ( destination.x - x > speed )
                    dx = speed
                if ( x > destination.x ) and ( x - destination.x > speed )
                    dx = -speed
                if ( y < destination.y ) and ( destination.y - y > speed )
                    dy = speed
                if ( y > destination.y ) and ( y - destination.y > speed )
                    dy = -speed
        movePlayer dx, dy

## Splash Screen

At login time, the game shows a title screen called a "splash screen."  The
following function supports doing so.

    drawSplashScreen = ( imageURL ) ->
        if not currentStatus.splashImage?
            currentStatus.splashImage = new Image
            currentStatus.splashImage.src = imageURL
        if currentStatus.splashImage.complete
            context = gameview.getContext '2d'
            context.drawImage currentStatus.splashImage, 0, 0,
                gameview.width, gameview.height

## Handling Map Clicks

If the player clicks on a region that sits within a command box in their
HUD, then we want to issue that command.

When the player clicks elsewhere on the map, we must check to see if the
server wants to know about that.  If it does, then we must send a message,
after having converted the coordinates from screen to world.

In all other cases, the player was just trying to use the click for motion.
In that case, we store the player's click destination so that we can have
the avatar attempt to walk there over time.

    whereIWantToGo = null
    getWhereIWantToGo = -> whereIWantToGo
    setWhereIWantToGo = ( destination ) -> whereIWantToGo = destination
    ( $ '#gameview' ).on 'click', ( event ) ->
        if currentStatus.dead then return
        screencoords =
            x : event.pageX - this.offsetLeft
            y : event.pageY - this.offsetTop
        for own box, command of HUDZones
            [ left, top, right, bottom ] =
                ( parseInt i for i in box.split ',' )
            if left <= screencoords.x and screencoords.x <= right
                if top <= screencoords.y and screencoords.y <= bottom
                    socket.emit 'command', name : command
                    return
        mapcoords = screenCoordsToMapCoords screencoords.x, screencoords.y
        listeners = $ '.map-click'
        if listeners.length
            socket.emit 'ui event',
                type : 'map click'
                location : mapcoords
                id : listeners.get( 0 ).getAttribute( 'id' )[6..]
        else
            setWhereIWantToGo mapcoords
