
# Expand/Collapse Command Pane

The expander is the button used to expand/collapse the command pane.  The
expandee is that pane which gets expanded/collapsed.

    expander = $ '#rightpaneexpander'
    expandee = $ '#rightpane'

The following two functions fill the button for expanding/collapsing the
command pane with appropriate imagery.

    showCommandExpander = ( show = yes )->
        expander.get( 0 ).innerHTML = "<img
            src='#{if show then 'plus' else 'minus'}.png'>"
    showCommandExpander no

When the expander is clicked, toggle the expandee and change the expander's
icon to indicate its toggling nature.

    ( $ '#rightpaneexpander' ).click ->
        expandee.toggle 200, ->
            showCommandExpander not expandee.is ':visible'

# Web Socket Connection to Server

Establish a web socket connection to the server for ongoing transfer of game
data.

    socket = io.connect document.URL, reconnect : false
    socket.on 'disconnect', console.log

If the server sends us a "show ui" message, we pass it off to a function
defined in a separate source file for handling such requests.

    socket.on 'show ui', ( data ) -> showUI data
