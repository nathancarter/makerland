
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
    ipc.on 'addMyUniverse', ( data ) ->
        data.name = data.name.replace /"/g, '\\"'

The `element` will be the entire box representing the universe in question.

        element = document.createElement 'div'
        color = if data.state is 'closed' then 'default' else 'success'
        if data.state is 'open-to-all'
            if data.externalIP
                badge = "#{data.numPlayers} players inside"
                color = 'success'
            else
                badge = "opening..."
                color = 'warning'
        else if data.state is 'open-to-me'
            if data.internalIP
                badge = "#{data.numPlayers} players inside"
                color = 'success'
            else
                badge = "opening..."
                color = 'warning'
        else
            badge = "closed"
            color = 'default'
        element.setAttribute 'class', "panel panel-#{color}"

First, its heading text.

        heading = document.createElement 'div'
        heading.setAttribute 'class', 'panel-heading'
        heading.innerHTML =
            "<h3 class='panel-title'>#{data.name} &nbsp; &nbsp; &nbsp;
            <span class='badge'>#{badge}</span> &nbsp; &nbsp; &nbsp;</h3>"
        visit = document.createElement 'span'
        visit.innerHTML += "<button type='button'
            id='#{safeName( data.name )}-visit'
            class='btn btn-#{color}'>Visit</button>"
        heading.childNodes[0].appendChild visit
        element.appendChild heading
        inside = document.createElement 'div'
        inside.setAttribute 'class', 'panel-body'
        inside.innerHTML =
            if data.state is 'open-to-all' and data.externalIP
                "<p>Link for external visitors: #{data.externalIP}</p>"
            else ""
        element.appendChild inside

Next, the row of buttons inside the universe panel.

        div = document.createElement 'div'
        group = document.createElement 'span'
        group.setAttribute 'class', 'btn-group'
        group.setAttribute 'role', 'group'
        buttonHTML = ( id, text ) ->
            "<button type='button' id='#{safeName( data.name )}-#{id}'
            #{if data.state isnt 'closed' then 'disabled="disabled"' \
                else ''}class='btn btn-default btn-xs'>#{text}</button> "
        group.innerHTML += buttonHTML 'copy', 'Copy'
        group.innerHTML += buttonHTML 'rename', 'Rename'
        group.innerHTML += buttonHTML 'delete', 'Delete'
        div.appendChild group
        div.appendChild document.createTextNode ' - '
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
        inside.appendChild div

Add the element to the left column.

        document.getElementById( 'my-universes-column' )
        .appendChild element

Add event handlers to all of its buttons.

        for own key, value of states
            do ( key ) ->
                $( "\##{safeName( data.name )}-#{key}" ).on 'click',
                ( event ) ->
                    if key is 'closed' and data.numPlayers > 0 and \
                       not confirm "Any players in that universe will be
                            kicked out if you close it.
                            \nNumber of players in that universe now:
                            #{data.numPlayers}.
                            \nDo you wish to close it?"
                        event.preventDefault()
                        return false
                    ipc.send 'universe state set',
                        name : data.name
                        state : key
        $( "\##{safeName( data.name )}-copy" ).on 'click', ->
            ipc.send 'universe action',
                name : data.name
                action : 'copy'
        $( "\##{safeName( data.name )}-rename" ).on 'click', ->
            ( $ '#rename-dialog' ).modal 'show'
            ( $ '#rename-cancel' ).off 'click'
            ( $ '#rename-confirm' ).off 'click'
            setTimeout ( -> ( $ '#rename-input' ).focus() ), 500
            ( $ '#rename-cancel' ).on 'click', ->
                ( $ '#rename-dialog' ).modal 'hide'
            ( $ '#rename-confirm' ).on 'click', ->
                ( $ '#rename-dialog' ).modal 'hide'
                ipc.send 'universe action',
                    name : data.name
                    action : 'rename'
                    value : ( $ '#rename-input' ).val()
                ( $ '#rename-input' ).val ''
        $( "\##{safeName( data.name )}-delete" ).on 'click', ->
            if confirm '!!!!! WARNING !!!!!
                    \n!!!!! WARNING !!!!!
                    \n!!!!! WARNING !!!!!
                    \n
                    \nThis will PERMANENTLY remove this universe!
                    \nAre you sure you want to delete it?
                    \n(Think of the bunnies.)'
                ipc.send 'universe action',
                    name : data.name
                    action : 'delete'
        visit = $ "\##{safeName( data.name )}-visit"
        visit.prop 'disabled', data.state is 'closed' or not data.internalIP
        visit.on 'click', -> ipc.send 'visit my universe', data.name

The function for the right column is simpler.

    ipc.on 'addOtherUniverse', ( data ) ->
        data.name = data.name.replace /"/g, '\\"'

The `element` will be the entire box representing the universe in question.

        element = document.createElement 'div'
        element.setAttribute 'class', "panel panel-success"

First, its heading text.

        heading = document.createElement 'div'
        heading.setAttribute 'class', 'panel-heading'
        heading.innerHTML =
            "<h3 class='panel-title'>#{data.name} &nbsp; &nbsp; &nbsp;</h3>"
        visit = document.createElement 'span'
        visit.innerHTML += "<button type='button'
            id='#{safeName( data.name )}-visit-other'
            class='btn btn-success'>Visit</button>"
        heading.childNodes[0].appendChild visit
        element.appendChild heading
        inside = document.createElement 'div'
        inside.setAttribute 'class', 'panel-body'
        inside.innerHTML = "<p>http://#{data.externalIP}:#{data.port}</p>"
        element.appendChild inside

Add the element to the left column.

        document.getElementById( 'other-universes-column' )
        .appendChild element

Add event handlers to its one button.

        visit = $ "\##{safeName( data.name )}-visit-other"
        visit.on 'click', -> ipc.send 'visit other universe', data.name

And a function for clearing either column.

    ipc.on 'clearColumn', ( mine ) ->
        column = "#{if mine then 'my' else 'other'}-universes-column"
        document.getElementById( column ).innerHTML = ''

Similar to the universe adding functions, but can add any HTML to either
column, rather than a specific universe element.

    ipc.on 'addMessage', ( mine, text ) ->
        column = "#{if mine then 'my' else 'other'}-universes-column"
        element = document.createElement 'div'
        element.innerHTML = text.replace /"/g, '\\"'
        document.getElementById( column ).appendChild element

Add event handlers to the "Create Universe" and "Quit" buttons.

    $ ->
        $( '#create-button' ).on 'click', ->
            window.location.href = 'create.html'
        $( '#quit-button' ).on 'click', ->
            if confirm 'Quitting closes all your universes.  Anyone in them
                    will be kicked out.  Do you want to proceed?'
                ipc.send 'clicked button', 'quit'
