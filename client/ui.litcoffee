
# User Interface Elements

This file contains functions for creating user interface elements for the
command pane.

This first function takes the data from the server and converts it into HTML
code for UI widgets, then places that inside the command pane on the right
of the game view.

    showUI = ( data ) ->
        commandPane = ( $ '#rightpane' ).get 0
        while commandPane.firstChild
            commandPane.removeChild commandPane.firstChild
        html = "<div class='container' id='commandui'><form>"
        focus = null
        cancel = null
        for element in data
            row = dataToRow element
            focus or= row.focus
            cancel or= row.cancel
            html += row.code
        html += "</form></div>"
        commandPane.innerHTML = html
        if focus then document.getElementById( focus ).focus()
        ( $ commandPane.childNodes[0] ).submit ( e ) -> e.preventDefault()
        ( $ commandPane ).keyup ( e ) ->
            if e.keyCode is 27 then ( $ '#'+cancel ).click()

It uses the following function to create an array of cells forming an
individual row in the table that populates that command pane.

    dataToCells = ( data ) ->
        cancel = data.cancel
        delete data.cancel
        attrs = ''
        for own key, value of data
            if key isnt 'name' and key isnt 'value'
                attrs += " #{key}='#{value}'"
        focus = undefined
        result = switch data.type
            when 'text' then [ "<p#{attrs}>#{data.value}</p>" ]
            when 'string input'
                focus = "input_#{data.name}"
                [
                    "<input type='text' id='input_#{data.name}'
                            class='form-control' placeholder='#{data.name}'
                            style='width: 100%'#{attrs}>
                     </input>"
                ]
            when 'password input'
                focus = "input_#{data.name}"
                [
                    "<input type='password' id='input_#{data.name}'
                            class='form-control' placeholder='#{data.name}'
                            style='width: 100%'#{attrs}>
                     </input>"
                ]
            when 'action'
                type = if data.default then 'submit' else 'button'
                name = data.value.replace /\s/g, '_'
                cancel and= "button_#{name}"
                focus = "button_#{name}"
                [
                    "<input type='#{type}' value='#{data.value}'
                            style='width: 100%'#{attrs}
                            id='button_#{name}' class='btn btn-default'
                            onclick='uiButtonClicked(this)'>
                     </input>"
                ]
            else [ "<p#{attrs}>#{JSON.stringify data}</p>" ]
        result.focus = focus
        result.cancel = cancel
        result

And this function converts an array of cells into a table row.

    dataToRow = ( data ) ->
        cells = dataToCells data
        code : "<div class='space-above-below'>
            #{cells.join '</div><div class="space-above-below">'}</div>",
        focus : cells.focus
        cancel : cells.cancel

This function extracts from any input elements in the right pane their
values, and stores them in a JSON object that can be sent to the server.

    dataFromUI = ->
        inputs = ( ( $ '#rightpane' ).get 0 ).getElementsByTagName 'input'
        result = { }
        for input in inputs
            id = input.getAttribute 'id'
            if id?[...6] is 'input_'
                name = id[6..]
                switch input.getAttribute 'type'
                    when 'text', 'password' then value = input.value
                    else value = undefined
                result[name] = value
        result

We also need an event handler for buttons added to the UI.  This is it.  It
merely tells the server that the client clicked a button.

    window.uiButtonClicked = ( button )->
        event = dataFromUI()
        event.type = 'action taken'
        event.action = button.value
        socket.emit 'ui event', event
