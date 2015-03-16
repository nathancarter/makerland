
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
    ( player, list, title, check = ( -> yes ),
      save = ( -> player.showCommandUI() ),
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
                        list.splice i, 1
                        again()
                ]
        controls.push [
            type : 'string input'
            name : 'new entry'
        ,
            type : 'action'
            value : 'Add'
            action : ( event ) ->
                if check event['new entry']
                    list.push event['new entry']
                    return again()
                player.showOK "The entry \"#{event['new entry']}\" is not
                    valid for this list.
                    #{if typeof okay is 'string' then okay}", again
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

## Editing a list of authors

A common use-case for editing a list of strings is editing the list of
authors for a database table entry.  We provide that common functionality
here as a convenience function.

The `check` function just verifies that an author exists as a player in the
game.  The caller must provide the player object, the table object, the
entry name, and the callback function to use for returning to the containing
UI.

    module.exports.editAuthorsList = ( player, table, entry, callback ) ->
        check = ( newAuthor ) ->
            newAuthor = newAuthor.toLowerCase()
            if not require( './database' ).accounts.exists newAuthor
                "The name \"#{newAuthor}\" does not belong to any
                player in the game."
            else
                yes
        save = ( newAuthorsList ) ->
            table.setAuthors entry, newAuthorsList
            callback()
        module.exports.editListUI player, table.getAuthors( entry ),
            "Editing authors for cell type #{entry}", check, save, callback

## "Are you sure?" prompt

It is very common to want to prompt a user, before a serious action is
taken, to see if they really want to do it.  The following function makes it
easy for clients to do so.

Provide the player object, text describing the action, and callbacks to run
in the two possible cases (doing the action or cancelling it).  The text
parameter will be used as shown in the code immediately below.

    module.exports.areYouSure = ( player, actionText, action, cancel ) ->
        if not /[.?!]$/.test actionText then actionText += '.'
        player.showUI
            type : 'text'
            value : "<h3>Are you sure?</h3>
                <p>You are about to #{actionText}
                Are you sure you want to proceed?</p>"
        ,
            type : 'action'
            value : 'Cancel'
            cancel : yes
            action : cancel
        ,
            type : 'action'
            value : 'Yes, proceed'
            action : action
