
# Server-Side UI Generation Tools

This module provides conveniences for creating user interfaces to present
to players.  Each function in this module will usually take the player as
the first parameter, and a callback as the last parameter.  It will present
to the given player some UI defined by the parameters in between, then call
the callback function when the player exits that UI.  The callback function
should therefore present the previous (containing) UI to the player; such
callback functions default to being the `showCommandUI` function in the
player object.  Sometimes a function will take two callbacks, one if the
player accepts/approves the UI (e.g., exits with "OK" or "Apply" or "Save")
and one if the player cancels.

## Editing a list of strings

The following function shows the player the given list of strings and allows
the player to edit it.  The player can add or remove entries from the list.
The list will be displayed with the given title.  The initial value of the
list is passed as a parameter, and will be interpreted as a list of strings.
(E.g., a list of integers will be turned into strings.)

Any entry the player attempts to add to the list will first be tested for
validity using the `check` routine given.  If that routine yields `true`,
the entry can be added.  If it yields anything else, it cannot.  If the
`check` routine yields a string as the result, that will be used in the
error message the player sees; good error messages are informative, so
`check` routines should return string explanations when possible.

If the player ends the editing with the Save button, then the `save`
callback is called, passing the new list of strings.  If the player ends
with the Cancel button, then the `cancel` callback is called, passing no
parameters.  Both callbacks default to showing the main command UI.

    module.exports.editListUI =
    ( player, list, title, check = -> yes, save = -> player.showCommandUI(),
      cancel = -> player.showCommandUI() ) ->
        again = -> module.exports.editListUI player, list, title, check,
            save, cancel
        controls = [
            type : 'text'
            value : "<h3>#{title}</h3>"
        ]
        list = list.slice()
        for i in [0...list.length]
            do ( i ) ->
                controls.push [
                    type : 'text'
                    value : "#{list[i]}"
                ,
                    type : 'action'
                    value : 'Remove'
                    action : ->
                        list = list.splice i, 1
                        again()
                ]
        controls.push [
            type : 'string input'
            value : 'new entry'
        ,
            type : 'action'
            value : 'Add'
            action : ( event ) ->
                okay = check event['new entry']
                if check isnt yes
                    return player.showOK "The entry
                        \"#{event['new entry']}\" is not valid for this
                        list. #{if typeof check is 'string' then check}",
                        again
                list.push event['new entry']
                again()
        ]
        controls.push
            type : 'action'
            value : 'Save'
            action : -> save list
        ,
            type : 'action'
            value : 'Cancel'
            cancel : yes
            action : -> cancel()
        player.showUI controls
