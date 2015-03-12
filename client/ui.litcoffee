
# User Interface Elements

This file contains functions for creating user interface elements for the
command pane.

This first function takes the data from the server and converts it into HTML
code for UI widgets, then places that inside the command pane on the right
of the game view.

    showUI = ( data ) ->

Clear out the contents of the command pane.

        commandPane = ( $ '#rightpane' ).get 0
        while commandPane.firstChild
            commandPane.removeChild commandPane.firstChild

Build the HTML code for all the UI described in `data`.  But for command
objects, save them to be processed separately.

        setWatchingChanges no
        html = ''
        focus = null
        cancel = null
        commands = categories : [ ]
        for element in data
            if element.type is 'command'
                commands[element.category] ?= [ ]
                commands[element.category].push element
                if element.category not in commands.categories
                    commands.categories.push element.category
                continue
            row = dataToRow element
            focus or= row.focus
            cancel or= row.cancel
            html += row.code

Now build a command UI from the categorized commands we lifted out of the
data.

        comhtml = ''
        for category in commands.categories
            comhtml += dataToRow( {
                type : 'category'
                name : category } ).code
            for command in commands[category]
                comhtml += dataToRow( command ).code
        html = comhtml + html

Fill the command pane with the HTML for the entire UI.  Then install the
change handler on all newly-created controls.

        commandPane.innerHTML = "<div class='container'
            id='commandui'><form>#{html}</form></div>"
        ( $ '#rightpane input, select' ).change window.uiElementChanged

If we found a UI element that should have focus, give it focus; if there is
an element that should be the default button or the cancel button, set up
handlers for those as well.

        if focus then document.getElementById( focus )?.focus()
        ( $ commandPane.childNodes[0] ).submit ( e ) -> e.preventDefault()
        ( $ commandPane ).keyup ( e ) ->
            if e.keyCode is 27 then ( $ '#'+cancel ).click()

It uses the following function to create an array of cells forming an
individual row in the table that populates that command pane.

    dataToCells = ( data ) ->
        if data instanceof Array
            result = [ ]
            for datum in data
                cells = dataToCells datum
                result = result.concat cells
                result.cancel = cells.cancel
                result.focus = cells.focus
            return result
        cancel = data.cancel
        delete data.cancel
        attrs = ''
        for own key, value of data
            if key isnt 'name' and key isnt 'value' and key isnt 'id'
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
            when 'choice'
                name = data.name[0].toUpperCase() + data.name[1..]
                focus = "input_#{data.name}"
                [
                    "<label for='input_#{data.name}'>#{name}:</label>
                    <select class='form-control' id='input_#{data.name}'>
                    #{for own key, value of data.choices
                        selected = if value is data.selected \
                            then 'selected' else ''
                        "<option value='#{value}' #{selected}
                         >#{key}</option>"}
                    </select>"
                ]
            when 'action'
                type = if data.default then 'submit' else 'button'
                name = data.value.replace /\s/g, '_'
                cancel and= "button_#{name}"
                focus = "button_#{name}"
                buttonType = if data.default then 'btn-primary' else \
                    if cancel then 'btn-danger' else 'btn-default'
                [
                    "<input type='#{type}' value='#{data.value}'
                            style='width: 100%'#{attrs}
                            id='button_#{data.id}' class='btn #{buttonType}'
                            onclick='uiButtonClicked(this)'>
                     </input>"
                ]
            when 'category'
                name = data.name[0].toUpperCase() + data.name[1..]
                [
                    "<div class='panel panel-default'>
                        <div class='panel-body'>#{name} Commands
                    </div></div>"
                ]
            when 'command'
                [
                    "<button type='button' value='#{data.name}'#{attrs}
                            id='command_button_#{data.name}'
                            class='btn btn-default' style='width:100%'
                            data-toggle='tooltip' data-placement='left'
                            title='#{data.help.replace /'/g, '&apos;'}'
                            onclick='uiCommandClicked(this)'>
                        <img src='#{data.icon}'
                              onclick='uiCommandClicked(
                                  document.getElementById(
                                      \"command_button_#{data.name}\"))'/>
                        #{data.name}
                     </button>"
                    "<p#{attrs}>#{data.shortInfo}</p>"
                ]
            when 'watcher'
                setWatchingChanges yes
                [ ]
            else [ "<p#{attrs}>#{JSON.stringify data}</p>" ]
        result.focus = focus
        result.cancel = cancel
        result

And this function converts an array of cells into a table row.

    dataToRow = ( data ) ->
        cells = dataToCells data
        if cells.length is 0 then return code : ''
        divclass = "space-above-below col-xs-#{12/cells.length}"
        code : "<div class='row'><div class='#{divclass}'>
            #{cells.join "</div><div class='#{divclass}'>"}</div></div>",
        focus : cells.focus
        cancel : cells.cancel

This function extracts from any input elements in the right pane their
values, and stores them in a JSON object that can be sent to the server.

    dataFromUI = ->
        result = { }
        for input in ( $ '#rightpane input, #rightpane select' ).get()
            id = input.getAttribute 'id'
            if id?[...6] is 'input_'
                name = id[6..]
                value = undefined
                if input.getAttribute( 'type' ) in [ 'text', 'password' ]
                    value = input.value
                if input.tagName is 'SELECT'
                    value = input.options[input.selectedIndex].value
                result[name] = value
        result

We also need an event handler for buttons added to the UI.  This is it.  It
merely tells the server that the client clicked a button.

    window.uiButtonClicked = ( button ) ->
        event = dataFromUI()
        event.type = 'action taken'
        event.id = button.getAttribute( 'id' )[7..]
        socket.emit 'ui event', event

We also need an event handler for commands added to the UI, much like the
one above.

    window.uiCommandClicked = ( button ) ->
        socket.emit 'command', name : button.value.toLowerCase()

We also need a handler for any change in any UI element, because sometimes
the server wants to be notified about that.

    watchingChanges = no
    setWatchingChanges = ( flag ) -> watchingChanges = flag
    window.uiElementChanged = ( event ) ->
        if not watchingChanges then return
        event = dataFromUI()
        event.type = 'contents changed'
        socket.emit 'ui event', event
