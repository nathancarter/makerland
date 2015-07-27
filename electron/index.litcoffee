
# Scripts supporting Electron app main window

This is thrown together now and mostly experimental.  It doesn't do much,
and is poorly documented.  Try back later.

Load the inter-process communication module, for listening to the main
process.

    ipc = require 'ipc'

Converts any text to/from a name that can be used as an element ID.

    safeName = ( str ) ->
        encodeURIComponent( str ).replace /\%/g, '___'

Whenever it tells us to add a universe, create the UI elements that show a
universe in either the left or right column.

    states =
        'closed' : 'Closed'
        'open-to-me' : 'Open to me'
        'open-to-all' : 'Open to all'
    ipc.on 'addUniverse', ( mine, name, state ) ->
        name = name.replace /"/g, '\\"'
        column = "#{if mine then 'my' else 'other'}-universes-column"
        element = document.createElement 'div'
        element.setAttribute 'class', 'thumbnail'
        element.innerHTML = '<h4>' + name + '</h4><p>Some text here.</p>'
        div = document.createElement 'div'
        group = document.createElement 'span'
        group.setAttribute 'class', 'btn-group'
        group.setAttribute 'role', 'group'
        buttonHTML = ( id, text ) ->
            "<button type='button' id='#{safeName( name )}-#{id}'
            data-toggle='button' class='btn btn-default
            #{if state is id then ' active' else ''}'>#{text}</button>"
        for own key, value of states
            group.innerHTML += buttonHTML key, value
        div.appendChild group
        div.appendChild document.createTextNode ' - '
        visit = document.createElement 'span'
        visit.innerHTML += "<button type='button'
            id='#{safeName( name )}-visit'
            class='btn btn-primary'>Visit</button>"
        div.appendChild visit
        element.appendChild div
        element.appendChild document.createElement 'p'
        document.getElementById( column ).appendChild element
        for own key, value of states
            do ( key ) ->
                $( "\##{safeName( name )}-#{key}" ).on 'click', ->
                    ipc.send 'universe state set',
                        name : name
                        state : key
        $( "\##{safeName( name )}-visit" ).on 'click', ->
            confirm 'This does not yet work.'
    ipc.on 'clearColumn', ( mine ) ->
        column = "#{if mine then 'my' else 'other'}-universes-column"
        document.getElementById( column ).innerHTML = ''

Similar to the previous, but just adds any HTML to the column, rather than a
specific universe element.

    ipc.on 'addMessage', ( mine, text ) ->
        column = "#{if mine then 'my' else 'other'}-universes-column"
        element = document.createElement 'div'
        element.innerHTML = text.replace /"/g, '\\"'
        document.getElementById( column ).appendChild element

Add event handlerst to the "Create Universe" and "Quit" buttons.

    $ ->
        $( '#create-button' ).on 'click', ->
            ipc.send 'clicked button', 'create universe'
        $( '#quit-button' ).on 'click', ->
            ipc.send 'clicked button', 'quit'
