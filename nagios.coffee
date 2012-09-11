# Description:
#   This script receives pages in the formats
#        /usr/bin/curl -d host="$HOSTALIAS$" -d output="$SERVICEOUTPUT$" -d description="$SERVICEDESC$" -d type=service -d state="$SERVICESTATE$" $CONTACTADDRESS1$
#        /usr/bin/curl -d host="$HOSTNAME$" -d output="$HOSTOUTPUT$" -d type=host -d state="$HOSTSTATE$" $CONTACTADDRESS1$
#
# Author:
#   oremj

irc = require('irc')

module.exports = (robot) ->
    robot.router.post '/hubot/nagios/:room', (req, res) ->
        room = req.params.room

        host = irc.colors.wrap('orange', req.body.host)
        output = irc.colors.wrap('white', req.body.output)

        state = req.body.state
        if state == 'OK'
            state_color = 'light_green'
        else if state == 'CRITICAL'
            state_color = 'light_red'
        else if state == 'WARNING'
            state_color = 'yellow'
        else
            state_color = 'orange'
        state = irc.colors.wrap(state_color, state)

        if req.body.type == 'host'
            robot.messageRoom "##{room}", "nagios: #{host} is #{output}"
        else
            service = req.body.description
            robot.messageRoom "##{room}", "nagios: #{host}:#{service} is #{state}: #{output}"

        res.writeHead 204, { 'Content-Length': 0 }
        res.end()