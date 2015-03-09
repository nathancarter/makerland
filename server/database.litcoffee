
# Game Database Module

This module collects together in one place all database tables in the game.
Thus clients can just import this module and get all the rest for free.

    module.exports.tables = tables = [
        'accounts'
    ]

    for table in tables
        module.exports[table] = require "./#{table}"
