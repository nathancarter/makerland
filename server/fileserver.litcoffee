
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

Export one function, `serveFile`, that takes three parameters.  The first is
the name of the file requested, and the second is the response object to use
for transmitting the results.

The final parameter is an options object.  So far, it supports only one
option, `no-cdns`, which, if set to true, causes the server to behave as
follows.  If it is about to serve an `.html` file, it searches through its
content for all script and stylesheet tags, and if any point to a `.js` or
`.css` file from an external website, but the same file exists in a folder
called `from-cdns` locally, then the URL to the external file is replaced
with a relative URL to the local file.

    module.exports.serveFile = ( filename, response, options ) ->

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

        filename = path.join __dirname, '..', 'client', original = filename

Verify that the file exists.  If it does not, try to find the file in the
universe folder itself.  If even that fails, give a 404 error.

        fs.exists filename, ( exists ) ->
            settings = require './settings'
            if not exists
                alternateName = path.join settings.gameRoot, original
                if fs.existsSync alternateName # sync to simplify code here
                    filename = alternateName
                else
                    return sendErrorToClient response, 404, '404 Not Found'

If the file is not in the client folder or universe folder, we refuse to
serve it, or even to acknowledge that it exists, because that would be a big
security hole.  We could send a 403 Forbidden here, but that would be to
acknowledge that the requested file exists.

            canonical = path.normalize filename
            clientFolder =
                path.normalize path.join __dirname, '..', 'client'
            universeFolder = path.normalize settings.gameRoot
            if canonical[...clientFolder.length] isnt clientFolder and \
               canonical[...universeFolder.length] isnt universeFolder
                return sendErrorToClient response, 404, '404 Not Found'

Try to read the file.  If you cannot, give a 500 error.

            fs.readFile filename, 'binary', ( err, file ) ->
                if err
                    return sendErrorToClient response, 500, "#{err}\n"

We got the file's content, so apply the CDN-replacement filter if that
option has been set.

                extension = filename.split( '.' ).pop()
                if extension2mimetype[extension] is 'text/HTML' and \
                   options['no-cdns']
                    cdnsFolder = path.join __dirname, '..', 'client',
                        'from-cdns'
                    localCopies = fs.readdirSync cdnsFolder
                    re = /// <
                        (script[^<]+src|link[^<]+href) # tag and attribute
                        (\s*=\s*)                      # ...equals...
                        ('[^']+'|"[^"]+")              # attribute value
                        ///
                    updated = ''
                    prefix = path.relative path.dirname( filename ),
                        cdnsFolder
                    while match = re.exec file
                        updated += file[...match.index]
                        resource = match[3][1...-1]
                        withoutPath = resource.split( path.sep ).pop()
                        updated += if withoutPath in localCopies
                            "<#{match[1]}#{match[2]}'#{path.join \
                                prefix, withoutPath}'"
                        else
                            match[0]
                        file = file[match.index+match[0].length..]
                    file = updated + file

Finally, send the file content to the client.

                sendFileToClient response, file, extension

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
