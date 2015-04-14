
## Sounds Cache

We create a cache in which we'll store audio files we download from the game
server.  If the server tells us to, we erase something from the cache, so
that it will be fetched again the next time it's needed.

    soundsCache = { }
    getSoundData = ( index ) ->
        soundsCache[index] ?= new Audio \
            "db/sounds/#{index}/soundfile?#{encodeURIComponent new Date}"
        soundsCache[index]
    socket.on 'sound data changed', ( index ) ->
        delete soundsCache[index]

## Playing Sounds

If we get a message from the server telling us to play a sound, we do so
right away.

    socket.on 'play sound', ( index ) ->
        getSoundData( index ).play()
