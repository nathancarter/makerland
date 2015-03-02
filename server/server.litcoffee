
# Main Game Server

Start an HTTP server to serve game files.  Pass the responsibility off to
the file server, declared in the following separate module.

    fileserver = require './fileserver'

The following built-in node modules are relevant.

    http = require 'http'
    url = require 'url'

The entirety of the server is defined here.

    server = http.createServer ( request, response ) ->
        uri = ( url.parse request.url ).pathname
        if uri is '/'
            uri = 'client.html'
        fileserver.serveFile uri, response
    .listen 9999
