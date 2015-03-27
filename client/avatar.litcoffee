
# Avatar Drawing Routines

First, the data for the walk cycle of a stick figure.  The walk cycle has
four keyframes, which appear in the following array.  The entry for each
extremity is a triple, (x,y,b), where (x,y) is the point in the plane where
the extremity sits and b is the amount by which the joint for that limb is
bent.

    walkCycle = [
        head : [ 0, 1.1 ]
        hips : [ 0, 0.5 ]
        lfoot : [ -0.25, 0, 0.1 ]
        rfoot : [ 0.25, 0, 0 ]
        lhand : [ 0.15, 0.5, 0.1 ]
        rhand : [ -0.15, 0.5, 0.1 ]
    ,
        head : [ 0, 1 ]
        hips : [ 0, 0.4 ]
        lfoot : [ -0.35, 0.1, 0.25 ]
        rfoot : [ 0.35, 0, 0.25 ]
        lhand : [ 0.25, 0.5, 0.25 ]
        rhand : [ -0.25, 0.5, 0.25 ]
    ,
        head : [ 0, 1.1 ]
        hips : [ 0, 0.5 ]
        lfoot : [ -0.1, 0.2, 0.3 ]
        rfoot : [ 0, 0, 0 ]
        lhand : [ 0.05, 0.5, 0.1 ]
        rhand : [ 0, 0.5, 0.05 ]
    ,
        head : [ 0, 1.2 ]
        hips : [ 0, 0.6 ]
        lfoot : [ 0, 0.15, 0.25 ]
        rfoot : [ -0.1, 0, 0 ]
        lhand : [ 0, 0.5, 0.15 ]
        rhand : [ 0.1, 0.5, 0.1 ]
    ]

We now duplicate the first four keyframes of the walk cycle, but interchange
right and left, to complete the full cycle.

    for i in [0...4]
        original = walkCycle[i]
        walkCycle.push
            head : original.head.slice()
            hips : original.hips.slice()
            lfoot : original.rfoot.slice()
            rfoot : original.lfoot.slice()
            lhand : original.rhand.slice()
            rhand : original.lhand.slice()

There is also a standing pose that is not part of the walk cycle.

    standing =
        head : [ 0, 1 ]
        hips : [ 0, 0.5 ]
        lfoot : [ -0.15, 0, 0 ]
        rfoot : [ 0.15, 0, 0 ]
        lhand : [ 0.1, 0.5, 0 ]
        rhand : [ -0.1, 0.5, 0 ]

This routine takes two endpoints of a limb and puts a bend in the center of
the limb by an amount proportional to the final parameter.  The left
parameter is true if the avatar is facing left, false otherwise.

    bumpJoint = ( end1, end2, left, amount ) ->
        diff = x : end2.x - end1.x, y : end2.y - end1.y # vector from 1 to 2
        diff = x : -diff.y, y : diff.x # rotate that vector left 90 degrees
        if diff.x > 0 and left or diff.x < 0 and not left
            diff.x *= -1
            diff.y *= -1 # ensure it points left iff left parameter is true
        x : ( end1.x + end2.x )/2 + diff.x*amount
        y : ( end1.y + end2.y )/2 + diff.y*amount

Finally, the routine that draws an avatar in a given pose.  The context
parameter is the 2D graphics context to draw on.  The name parameter is the
avatar's name, as a string.  The position is that of the current player,
which may or may not be the avatar we're drawing, and is thus used to
compute the delta, so we know where on screen to put the avatar to be drawn.
The pose is a data structure of the same form as the keyframes above, though
it is often not exactly one of those keyframes, but rather an interpolation
between two.  The left parameter is a true or false value, saying which way
the player is facing (left or not).  The appearance parameter is a data
structure specifying data such as leg color, body color, height, and so on.

    drawAvatarInPose =
    ( context, name, position, pose, left, appearance ) ->
        cellSize = window.gameSettings.cellSizeInPixels
        if not cellSize then return
        myPosition = getPlayerPosition()
        if myPosition[0] isnt position[0] then return
        dx = ( position[1] - myPosition[1] ) * cellSize
        dy = ( position[2] - myPosition[2] ) * cellSize
        scale = cellSize/2 * ( appearance?.height or 1 )
        flip = if left then -1 else 1
        point = ( array ) ->
            x : gameview.width/2 + dx + array[0]*scale*flip
            y : gameview.height/2 + dy - array[1]*scale
        head = point pose.head
        hips = point pose.hips
        lfoot = point pose.lfoot
        lknee = bumpJoint hips, lfoot, left, pose.lfoot[2]
        rfoot = point pose.rfoot
        rknee = bumpJoint hips, rfoot, left, pose.rfoot[2]
        shoulder = x : hips.x*0.2+head.x*0.8, y : hips.y*0.2 + head.y*0.8
        lhand = point pose.lhand
        lelbow = bumpJoint shoulder, lhand, not left, pose.lhand[2]
        rhand = point pose.rhand
        relbow = bumpJoint shoulder, rhand, not left, pose.rhand[2]
        context.lineWidth = appearance?.thickness or 1
        context.lineCap = 'round'
        context.strokeStyle = appearance?.legColor or '#000000'
        context.beginPath()
        context.moveTo lfoot.x, lfoot.y
        context.lineTo lknee.x, lknee.y
        context.lineTo hips.x, hips.y
        context.lineTo rknee.x, rknee.y
        context.lineTo rfoot.x, rfoot.y
        context.stroke()
        context.strokeStyle = appearance?.bodyColor or '#000000'
        context.beginPath()
        context.moveTo shoulder.x, shoulder.y
        context.lineTo hips.x, hips.y
        context.stroke()
        context.strokeStyle = appearance?.armColor or '#000000'
        context.beginPath()
        context.moveTo lhand.x, lhand.y
        context.lineTo lelbow.x, lelbow.y
        context.lineTo shoulder.x, shoulder.y
        context.lineTo relbow.x, relbow.y
        context.lineTo rhand.x, rhand.y
        context.stroke()
        context.fillStyle = context.strokeStyle =
            appearance?.headColor or '#000000'
        hs = appearance?.headSize or 0.1
        context.beginPath()
        context.arc head.x, head.y, hs*scale, 0, 2 * Math.PI, false
        context.fill()
        context.font = '16px serif'
        size = context.measureText name
        context.fillText name, head.x-size.width/2, head.y-20

The following function takes the same set of parameters as the previous,
except the pose and left parameters have been replaced with a motion
parameter.  The motion parameter is the avatar's most recent change in x
coordinate.  This routine computes the appropriate pose and left parameters,
then calls the previous routine to do the real drawing work.

Thus it uses the following global variable, which maps player names to the
point in the walk cycle that they're currently at (a time value from 0 to 8,
including fractional values in between).

    cyclePoint = { }

Now the routine itself.  This is the main API for this file, and is called
from the `gameview` file.

    drawAvatar = ( context, name, position, motion, appearance ) ->
        if not motion
            drawAvatarInPose context, name, position, standing, yes,
                appearance
            cyclePoint[name] = 0
        else
            rate = 5
            if name not of cyclePoint
                cyclePoint[name] = 0
            else
                cyclePoint[name] = ( cyclePoint[name] + 1 ) % (8*rate)
            time = cyclePoint[name]/rate
            pose1 = walkCycle[Math.floor time]
            pose2 = walkCycle[(Math.ceil time)%8]
            pct = time - Math.floor time
            pose3 = { }
            for own key of pose1
                pose3[key] = ( pose1[key][i]*(1-pct) + pose2[key][i]*pct \
                    for i in [0...pose1[key].length] )
            drawAvatarInPose context, name, position, pose3,
                motion < 0, appearance
