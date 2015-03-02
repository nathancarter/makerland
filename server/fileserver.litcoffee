
# File Server

Serves up plain old files over HTTP, nothing else.

Start by loading the requisite modules.

    fs = require( 'fs' );
    path = require( 'path' );

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

Find the full path to the filename.

        filename = path.join process.cwd(), 'client', filename

Verify that the file exists.  If it does not, give a 404 error.

        fs.exists filename, ( exists ) ->
            if not exists
                response.writeHead 404, 'Content-Type' : 'text/plain'
                response.write '404 Not Found\n'
                response.end()
                return

Try to read the file.  If you cannot, give a 500 error.

            fs.readFile filename, 'binary', ( err, file ) ->
                if err
                    response.writeHead 500, 'Content-Type' : 'text/plain'
                    response.write err + '\n'
                    response.end()
                    return

We got the file's content, so send it.

                details = 'Cache-Control' : 'max-age=86400' # 1 day
                extension = filename.split( '.' ).pop()
                if extension2mimetype.hasOwnProperty extension
                    details[extension] = extension2mimetype[extension]
                response.writeHead 200, details
                response.write file, 'binary'
                response.end()
