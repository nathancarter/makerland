
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
    for i in [0...4]
        original = walkCycle[i]
        walkCycle.push
            head : original.head.slice()
            hips : original.hips.slice()
            lfoot : original.rfoot.slice()
            rfoot : original.lfoot.slice()
            lhand : original.rhand.slice()
            rhand : original.lhand.slice()
    cyclePoint = { }
    standing =
        head : [ 0, 1 ]
        hips : [ 0, 0.5 ]
        lfoot : [ -0.15, 0, 0 ]
        rfoot : [ 0.15, 0, 0 ]
        lhand : [ 0.1, 0.5, 0 ]
        rhand : [ -0.1, 0.5, 0 ]
    bumpJoint = ( end1, end2, left, amount ) ->
        diff = x : end2.x - end1.x, y : end2.y - end1.y # vector from 1 to 2
        diff = x : -diff.y, y : diff.x # rotate that vector left 90 degrees
        if diff.x > 0 and left or diff.x < 0 and not left
            diff.x *= -1
            diff.y *= -1 # ensure it points left iff left parameter is true
        x : ( end1.x + end2.x )/2 + diff.x*amount
        y : ( end1.y + end2.y )/2 + diff.y*amount
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
