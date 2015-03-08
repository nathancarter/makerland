
# Expand/Collapse Command Pane

The expander is the button used to expand/collapse the command pane.  The
right pane is that pane which gets expanded/collapsed.

    expander = $ '#rightpaneexpander'
    leftpane = $ '#leftpane'
    rightpane = $ '#rightpane'
    gameview = ( $ '#gameview' ).get 0

The following functions define how to expand and collapse the command pane,
and how to update the button for doing so to reflect its next action.

    commandPaneExpanded = -> rightpane.width() > 0
    updateExpander = ->
        expanded = commandPaneExpanded()
        expander.get( 0 ).innerHTML = "<img
            src='#{if expanded then 'minus' else 'plus'}.png'>"
    expandCommandPane = ->
        rightpane.animate { width : '350px' }, 200, -> updateExpander()
        leftpane.animate { right : '350px' }, 200
        expander.animate { right : '350px' }, 200
    collapseCommandPane = ->
        rightpane.animate { width : '0px' }, 200, -> updateExpander()
        leftpane.animate { right : '0px' }, 200
        expander.animate { right : '0px' }, 200
    toggleCommandPane = ->
        if commandPaneExpanded() then collapseCommandPane() \
        else expandCommandPane()
    expandCommandPane()

When the expander is clicked, toggle the right pane and change the
expander's icon to indicate its toggling nature.

    expander.click toggleCommandPane

# Web Socket Connection to Server

Establish a web socket connection to the server for ongoing transfer of game
data.

    socket = io.connect document.URL, reconnect : false
    socket.on 'disconnect', ( event ) ->
        clearStatus()
        rightpane.get( 0 ).innerHTML = "
            <div class='container' id='commandui'><form>
            <div class='space-above-below col-xs-12'>
            <p align='center'>Game closed.</p></div>
            <div class='space-above-below col-xs-12'>
            <input type='button' value='Reload Game' style='width: 100%'
                   class='btn btn-success' onclick='location.reload()'>
            </input></form></div>
            "
        expandCommandPane()

If the server sends us a "show ui" message, we pass it off to a function
defined in a separate source file for handling such requests.

    socket.on 'show ui', ( data ) -> showUI data

If the server sends us a status update message, save it so that it can be
used in drawing the game view.  Also, we use `movePlayer` to notify a
newly-logged-in player of their location and vision distance.

    currentStatus = { }
    clearStatus = -> currentStatus = { }
    socket.on 'status', ( data ) ->
        currentStatus = JSON.parse data
        movePlayer 0, 0

If the server sends us a game settings message, we save that in a global
variable.

    window.gameSettings = { }
    socket.on 'settings', ( data ) -> window.gameSettings = data
