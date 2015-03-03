
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
        commandPane.innerHTML = \
            "<table border=0 cellpadding=2 cellspacing=6 width=100%>
             #{( dataToRow element for element in data ).join '\n'}
             </table>"

It uses the following function to create an array of cells forming an
individual row in the table that populates that command pane.

    dataToCells = ( data ) ->
        attrs = ''
        for key, value of data
            if key isnt 'name' and key isnt 'value'
                attrs += " #{key}='#{value}'"
        switch data.type
            when 'text' then [ "<p#{attrs}>#{data.value}</p>" ]
            when 'string input' then [
                data.name[0].toUpperCase() + data.name[1..] + ':'
                "<input type='text' id='input_#{data.value}'
                        style='width: 100%'#{attrs}>
                 </input>"
            ]
            when 'password input' then [
                data.name[0].toUpperCase() + data.name[1..] + ':'
                "<input type='password' id='input_#{data.value}'
                        style='width: 100%'#{attrs}>
                 </input>"
            ]
            when 'action' then [
                "<input type='button' value='#{data.value}'
                        style='width: 100%'#{attrs}>
                 </input>"
            ]
            else [ "<p#{attrs}>#{JSON.stringify data}</p>" ]

And this function converts an array of cells into a table row.

    dataToRow = ( data ) ->
        cells = dataToCells data
        td = "<td colspan=#{12/cells.length}>"
        "<tr>#{td}#{cells.join '</td>'+td}</td></tr>"
