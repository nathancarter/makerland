
# File Server

Serves up plain old files over HTTP, nothing else.

Start by loading the requisite modules.

    fs = require 'fs'
    path = require 'path'
    db = require './database'

Keep track of how to convert extensions on the filesystem to mime types in
the HTTP protocol.

    extension2mimetype =
        'png' : 'image/PNG'
        'html' : 'text/HTML'
        'js' : 'application/javascript'
        'css' : 'text/css'

Export one function, `serveFile`, that takes two parameters.  The first is
the name of the file requested, and the second is the response object to use
for transmitting the results.

    module.exports.serveFile = ( filename, response ) ->

If the filename is actually a request for a resource from the game database,
handle that separately from other files.

        dbinfo = db.parseDatabaseURL filename
        if dbinfo
            contents = db[dbinfo.table].getFile dbinfo.entry, dbinfo.key
            if contents?
                sendFileToClient response, contents
            else
                sendErrorToClient response, 404, '404 Not Found'
            return

Now we know it's not a request for a resource from the game database, but
for a typical file.  So we proceed.  Find the full path to the filename.

        filename = path.join process.cwd(), 'client', filename

Verify that the file exists.  If it does not, give a 404 error.

        fs.exists filename, ( exists ) ->
            if not exists
                return sendErrorToClient response, 404, '404 Not Found'

Try to read the file.  If you cannot, give a 500 error.

            fs.readFile filename, 'binary', ( err, file ) ->
                if err
                    return sendErrorToClient response, 500, "#{err}\n"

We got the file's content, so send it.

                sendFileToClient response, file, filename.split( '.' ).pop()

The following routine returns an error to a client.  The first parameter is
the response object to use, the second the error code as an integer, and the
last the text of the error message.

    sendErrorToClient = ( response, code, text ) ->
        response.writeHead code, 'Content-Type' : 'text/plain'
        response.write text
        response.end()

The following routine sends a file to the client.  The contents should be
provided as a Buffer object.  The extension is an optional parameter; if
provided, it will clue the server in to what kind of file it is, and let it
send a likely-correct MIME type.  The max age is an optional parameter, with
default one day.

    sendFileToClient = ( response, contents, extension, maxage = 86400 ) ->
        details = 'Cache-Control' : "max-age=#{maxage}"
        if extension? and extension2mimetype.hasOwnProperty extension
            details['Content-Type'] = extension2mimetype[extension]
        response.writeHead 200, details
        response.write contents, 'binary'
        response.end()
