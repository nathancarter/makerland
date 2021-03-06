
# Logs Table

This module implements a game database table for storing text logs of errors
that occurred when running code written by makers.

    { Table } = require './table'

It does so by subclassing the main Table class and adding log-file-specific
functionality.

    class LogsTable extends Table

## Constructor

The constructor just sets the name of the table.

        constructor : ->
            super 'logs', 'Maker Error Logs'

How many entries can an individual log have before it begins being
truncated?  How long can each entry be?

        logSizeLimit : 50
        lineSizeLimit : 1000

## Maker Database Browsing

This method overrides the maker's ability to access this table directly with
the database command, which also means we do not need to provide methods
such as `show`, `entries`, `add`, `remove`, and so forth.

        browse : ( player, callback ) =>
            entries = ( @get player.name, 'entries' ) ? [ ]
            entries = entries.join '</pre><pre>'
            entries = "<pre>#{entries or '(no log entries)'}</pre>"
            player.showUI
                type : 'text'
                value : "<h3>Your error log</h3>
                        <p>Errors generated by your code, with dates, times,
                        and descriptions, are listed below.</p>
                        <p>Scroll down if there is more than one screen
                        worth.  Newer entries are near the top.  Only the
                        most recent #{@logSizeLimit} entries are shown.</p>"
            ,
                type : 'action'
                value : 'Erase all entries'
                action : =>
                    @set player.name, 'entries', [ ]
                    @browse player, callback
            ,
                type : 'action'
                value : 'Done'
                cancel : yes
                action : callback
            ,
                type : 'text'
                value : "<h4>Log Entries:</h4>#{entries}"

## Logging

To add an entry to a maker's log, call the following function.  It truncates
any one line of the log if it's too long, and the log itself if it's too
long.

        logMessage : ( makerName, message ) =>
            message = message[...@lineSizeLimit]
            message = "#{new Date}\n#{message}"
            ( log = ( @get makerName, 'entries' ) ? [ ] ).unshift message
            if log.length > @logSizeLimit then log.pop()
            @set makerName, 'entries', log

To add an error entry, use this convenience function, which formats the
error message in a way convenient for the reader.  The parameters are the
name of the maker whose code caused the error, a description of the code
that caused the error (e.g., "behavior X"), the actual code that caused the
error, and the error object itself.

        logError : ( makerName, codeDescription, code, errorObject ) =>
            lines = code.split '\n'
            stack = errorObject.stack.split '\n'
            errorText = stack[0]
            re = /[:(](\d+):(\d+)[)]/.exec stack[0]
            if not re
                re = /[:(](\d+):(\d+)[)]/.exec stack[1]
                errorText += '\n' + stack[1]
            if re
                [ whole, line, column ] = re
                line = parseInt line ; column = parseInt column
                line -= errorObject.prefixLength ? 0
                start = Math.max 1, line - 3
                end = Math.min lines.length, line + 3
                lineNo = ( n ) -> "    #{n}. "[-5..]
                indent = ( n ) -> if n <= 0 then '' else ' ' + indent n-1
                lines = ( "#{lineNo start+i}#{L}" \
                    for L, i in lines[start-1..end-1] )
                if 0 <= line-start and line-start < lines.length
                    newline = lines[line-start][...column+4] + \
                        '<span style="background-color: red">'
                    lines[line-start] = lines[line-start][...column+4] + \
                        '<span style="background-color: red">' + \
                        ( lines[line-start][column+4] ? '(HERE)' ) + \
                        '</span>' + lines[line-start][column+5..]
            else if stack.length <= 10
                errorText = stack.join( '\n' ) + '\n...'
            else
                errorText = stack[..5].join( '\n' ) + '\n...\n' + \
                    stack[-5..].join( '\n' )
                console.log 'Error too large to log fully:',
                    stack.join '\n'
            @logMessage makerName,
                "<b><u>Error in: #{codeDescription}</u></b>
                \n<font color=red>#{errorText}</font>
                \n#{lines.join '\n'}"
            console.log "Logged error for maker \"#{makerName}.\""

## Exporting

The module then exports a single instance of the `LogsTable` class.

    module.exports = new LogsTable
