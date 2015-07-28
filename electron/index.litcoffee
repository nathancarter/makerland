
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
    ipc.on 'addUniverse', ( mine, data ) ->
        data.name = data.name.replace /"/g, '\\"'
        column = "#{if mine then 'my' else 'other'}-universes-column"
        element = document.createElement 'div'
        element.setAttribute 'class', 'thumbnail'
        html = "<h4>#{data.name}</h4>
            <p>Number of players now: #{data.numPlayers}</p>"
        html += if data.state is 'open-to-all'
            if data.externalIP
                "<p>External players can visit it at
                    #{data.externalIP}.</p><p>You can use the
                    Visit button below.</p>"
            else
                "<p>Setting up universe...</p>"
        else if data.state is 'open-to-me'
            if data.internalIP
                "<p>External players cannot visit this universe now.</p>
                 <p>You can use the Visit button below.</p>"
            else
                "<p>Setting up universe...</p>"
        else
            "<p>Universe is closed to visitors.<p>
             <p>You can open it using one of the buttons below.</p>"
        element.innerHTML = html
        div = document.createElement 'div'
        group = document.createElement 'span'
        group.setAttribute 'class', 'btn-group'
        group.setAttribute 'role', 'group'
        buttonHTML = ( id, text ) ->
            "<button type='button' id='#{safeName( data.name )}-#{id}'
            data-toggle='button' class='btn btn-default
            #{if data.state is id then ' active' else ''}'>#{text}</button>"
        for own key, value of states
            group.innerHTML += buttonHTML key, value
        div.appendChild group
        div.appendChild document.createTextNode ' - '
        visit = document.createElement 'span'
        visit.innerHTML += "<button type='button'
            id='#{safeName( data.name )}-visit'
            class='btn btn-primary'>Visit</button>"
        div.appendChild visit
        element.appendChild div
        element.appendChild document.createElement 'p'
        document.getElementById( column ).appendChild element
        for own key, value of states
            do ( key ) ->
                $( "\##{safeName( data.name )}-#{key}" ).on 'click',
                ( event ) ->
                    if key is 'closed' and data.numPlayers > 0 and \
                       not confirm "Any players in that universe will be
                            kicked out if you close it.\n
                            Number of players in that universe now:
                            #{data.numPlayers}.\n
                            Do you wish to close it?"
                        event.preventDefault()
                        return false
                    ipc.send 'universe state set',
                        name : data.name
                        state : key
        visit = $ "\##{safeName( data.name )}-visit"
        visit.prop 'disabled', data.state is 'closed' or not data.internalIP
        visit.on 'click', -> ipc.send 'visit universe', data.name
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
            if confirm 'Quitting closes all your universes.  Anyone in them
                    will be kicked out.  Do you want to proceed?'
                ipc.send 'clicked button', 'quit'
