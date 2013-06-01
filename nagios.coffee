# Description:
#   This script receives pages in the formats
#        /usr/bin/curl -d host="$HOSTALIAS$" -d output="$SERVICEOUTPUT$" -d description="$SERVICEDESC$" -d type=service -d notificationtype="$NOTIFICATIONTYPE$ -d state="$SERVICESTATE$" $CONTACTADDRESS1$
#        /usr/bin/curl -d host="$HOSTNAME$" -d output="$HOSTOUTPUT$" -d type=host -d notificationtype="$NOTIFICATIONTYPE$" -d state="$HOSTSTATE$" $CONTACTADDRESS1$
#
#   Based on a gist by oremj (https://gist.github.com/oremj/3702073)
#
# Configuration:
#   HUBOT_NAGIOS_URL - https://<user>:<password>@nagios.example.com/cgi-bin/nagios3
#
# Commands:
#   hubot nagios ack <host>:<service> <descr> - acknowledge alert
#   hubot nagios mute <host>:<service> <minutes> - delay the next service notification
#   hubot nagios recheck <host>:<service> - force a recheck of a service
#   hubot nagios all_alerts_off - useful in emergencies. warning: disables all alerts, not just bot alerts
#   hubot nagios all_alerts_on - turn alerts back on
#

nagios_url = process.env.HUBOT_NAGIOS_URL

module.exports = (robot) ->

  robot.router.post '/hubot/nagios/:room', (req, res) ->
    room = req.params.room
    host = req.body.host
    output = req.body.output
    state = req.body.state
    notificationtype = req.body.notificationtype

    if req.body.type == 'host'
      robot.messageRoom "#{room}", "nagios #{notificationtype}: #{host} is #{output}"
    else
      service = req.body.description
      robot.messageRoom "#{room}", "nagios #{notificationtype}: #{host}:#{service} is #{state}: #{output}"

    res.writeHead 204, { 'Content-Length': 0 }
    res.end()

  robot.respond /nagios ack(nowledge)? (.*):(.*) (.*)/i, (msg) ->
    host = msg.match[1]
    service = msg.match[2]
    message = msg.match[3] || ""
    call = "cmd.cgi"
    data = "cmd_typ=34&host=#{host}&service=#{service}&cmd_mod=2&sticky_ack=on&com_author=#{msg.envelope.user}&send_notification=on&com_data=#{encodeURIComponent(message)}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Your acknowledgement was received by nagios"

  robot.respond /nagios mute (.*):(.*) (\d+)/i, (msg) ->
    host = msg.match[1]
    service = msg.match[2]
    minutes = msg.match[3] || 30
    call = "cmd.cgi"
    data = "cmd_typ=9&cmd_mod=2&&host=#{host}&service=#{service}&not_dly=#{minutes}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Muting #{host}:#{service} for #{minutes}m"

  robot.respond /nagios recheck (.*):(.*)/i, (msg) ->
    host = msg.match[1]
    service = msg.match[2]
    call = "cmd.cgi"
    d = Date()
    start_time = "#{d.getUTCFullYear()}-#{d.getUTCMonth()}-#{d.getUTCDate()}+#{d.getUTCHours()}%3A#{d.getUTCMinutes()}%3A#{d.getUTCSeconds()}"
    data = "cmd_typ=7&cmd_mod=2&host=#{host}&service=#{service}&force_check=on&start_time=\"#{start_time}\""
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Scheduled to recheck #{host}:#{service} at #{start_time}"

  robot.respond /nagios (all_alerts_off|stfu|shut up)/i, (msg) ->
    call = "cmd.cgi"
    data = "cmd_typ=11&cmd_mod=2"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Ok, all alerts off. (this disables ALL alerts, not just mine.)"

  robot.respond /nagios all_alerts_on/i, (msg) ->
    call = "cmd.cgi"
    data = "cmd_typ=12&cmd_mod=2"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Ok, alerts back on"

nagios_post = (msg, call, data, cb) ->
  msg.http("#{nagios_url}/#{call}")
    .header('accept', '*/*')
    .header('User-Agent', "Hubot/#{@version}")
    .post(data) (err, res, body) ->
      cb body
