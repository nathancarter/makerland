
# Commands Module

This module will define all the commands available to players.  The module
object will be a mapping from command names to objects defining the
command's properties (description, help, code to run it, etc.).

    module.exports =

The quit command logs the player out of the game.

        quit :
            category : 'basic'
            shortInfo : 'Leave the game immediately'
            run : ( player ) -> player.socket.disconnect()
