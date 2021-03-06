
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
                okay = check event['new entry']
                if okay is yes
                    list.push event['new entry']
                    return again()
                player.showOK "The entry \"#{event['new entry']}\" is not
                    valid for this list.
                    #{if typeof okay is 'string' then okay else ''}", again
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

## Pick one item from a list of choices

This gives the player a prompt with the heading "Choose one:" followed by
any instructions provided as text.  The choices given are then presented in
a drop-down list.  The function calls the callback with null if the player
cancels, or the choice (as a string) if they choose one and click OK.  If
`selected` is on the list of choices, then it will be the one selected when
the UI appears.

    module.exports.pickFromList =
    ( player, instructions, choices, selected, callback ) ->
        player.showUI
            type : 'text'
            value : "<h3>Choose one:</h3><p>#{instructions}</p>"
        ,
            type : 'choice'
            name : 'choice'
            choices : choices
            selected : selected
        ,
            type : 'action'
            value : 'OK'
            default : yes
            action : ( data ) -> callback data.choice
        ,
            type : 'action'
            value : 'Cancel'
            cancel : yes
            action : -> callback null

## Editing a set of key-value pairs

This shows a UI for entering a set of key-value pairs.  But if it presented
that UI to the user in those terms ("Please enter a set of key-value pairs")
that would often be confusing.  Thus it accepts parameters for what to call
the keys and values.  For example, if you are mapping names of coins to
their values, you might set `keyName` to "name of coin" and `valueName` to
"value of coin" for example.  You should also provide a title for the UI.

The callback will be called with a parameter of null if the user cancels, or
with a valid object (which may have zero or more key-value pairs in it) that
is `JSON.stringify`able.  Any data the user entered as a key was treated as
a string; any data the user entered as a value was converted to one of the
following data types, in this order of priority.

 * a boolean if it's true/false/yes/no/on/off
 * a number if possible
 * a JSON object if JSON.parse succeeds
 * a string otherwise

This conversion is accomplished by the following auxiliary function, used in
the key-value-pair editing function defined further below.

    valueInputToData = ( input ) ->
        if input in [ 'true', 'yes', 'on' ] then return true
        if input in [ 'false', 'no', 'off' ] then return false
        finput = parseFloat input
        if not isNaN( finput ) and isFinite input then return finput
        try return JSON.parse input
        input

That function also has an inverse.

    dataToValueInput = ( data ) ->
        if data is true then return 'true'
        if data is false then return 'false'
        if typeof data is 'number' then return "#{data}"
        if typeof data is 'string' then return data
        try return JSON.stringify data
        "#{data}" # shouldn't happen, but just in case

We need one other auxiliary function, for taking the UI and forming the set
of key-value pairs from it.

    buildObjectFromUI = ( event ) ->
        result = { }
        for own key, value of event
            if key[...4] is 'key '
                count = key[4..]
                if event.hasOwnProperty "value #{count}"
                    result[value] = valueInputToData event["value #{count}"]
        result

Now the actual public-facing function itself.  The only parameter not yet
explained is "instructions," which must be text, but can be empty.  If
non-empty, it will be inserted below the title, explaining to the user
whatever you feel needs explaining about what they're editing.

    module.exports.editKeyValuePairs =
    ( player, keyName, valueName, title, instructions, initialData,
      callback ) =>
        again = ( data ) -> module.exports.editKeyValuePairs player,
            keyName, valueName, title, instructions, data, callback
        controls = [
            type : 'text'
            value : "<h3>#{title}</h3>"
        ]
        if instructions.length > 0 then controls.push
            type : 'text'
            value : instructions
        controls.push
            type : 'text'
            value : "Entries in the list below have \"#{keyName}\" on the
                left and \"#{valueName}\" on the right."
        count = 0
        for own key, value of initialData
            controls.push [
                type : 'string input'
                name : "key #{count}"
                value : key
            ,
                type : 'string input'
                name : "value #{count}"
                value : dataToValueInput value
            ]
            controls.push
                type : 'action'
                value : 'Remove previous'
                action : do ( count ) -> ( event ) ->
                    delete event["key #{count}"]
                    again buildObjectFromUI event
            count++
        if count is 0 then controls.push
            type : 'text'
            value : '(no entries in the list yet--you may add some)'
        controls = controls.concat [
            type : 'action'
            value : 'Add'
            action : ( event ) ->
                data = buildObjectFromUI event
                i = 1
                while data.hasOwnProperty "new #{keyName} #{i}"
                    i++
                data["new #{keyName} #{i}"] = "new #{valueName} #{i}"
                again data
        ,
            type : 'action'
            value : 'Done'
            default : yes
            action : ( event ) -> callback buildObjectFromUI event
        ,
            type : 'action'
            value : 'Cancel'
            cancel : yes
            action : ( event ) -> callback null
        ]
        player.showUI controls

Colors used in color-picker drop-downs across the game are stored in the
following object.  The subsequent function returns a color name given the
color code in hex.

    module.exports.colors =
        white    : '#FFFFFF'
        black    : '#000000'
        dark     : '#313131'
        gray     : '#626262'
        tan      : '#7E715D'
        dusty    : '#574C3C'
        orange   : '#943E0F'
        brown    : '#5F472F'
        honey    : '#99761B'
        gold     : '#C9BC0F'
        algae    : '#769028'
        grass    : '#397628'
        trees    : '#246024'
        sky      : '#28726E'
        royal    : '#800080'
        lavender : '#EFA9FE'
        camo     : '#59955C'
        russet   : '#8E2323'
    module.exports.colorName = ( hexcode ) ->
        hexcode = hexcode.toLowerCase()
        for own name, code of module.exports.colors
            return name if code.toLowerCase() is hexcode
        null
