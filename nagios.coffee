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
#   hubot nagios ack <host> <descr> - acknowledge host
#   hubot nagios ack <host>:<service> <descr> - acknowledge service
#   hubot nagios down <host> <minutes> <descr> - schedule downtime for the host
#   hubot nagios down <host>:<service> <minutes> <descr> - schedule downtime for the service
#   hubot nagios mute <host>:<service> <minutes> - delay the next service notification
#   hubot nagios recheck <host>:<service> - force a recheck of a service
#   hubot nagios all_alerts_off - useful in emergencies. warning: disables all alerts, not just bot alerts
#   hubot nagios all_alerts_on - turn alerts back on
#

nagios_url = process.env.HUBOT_NAGIOS_URL
process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = '0';

module.exports = (robot) ->
  # w=weeks d=days h=hours m=min default m
  parsetime = (time) =>
    lastchar = time[-1..]
    if lastchar == 'w'
      return time[..-2] * 60 * 24 * 7
    else if lastchar == 'd'
      return time[..-2] * 60 * 24
    else if lastchar == 'h'
      return time[..-2] * 60
    else if lastchar == 'm'
      return time[..-2]
    else
      return time

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

  robot.respond /nagios ack(nowledge)? ([^:\s]+) (.*)/i, (msg) ->
    host = msg.match[2]
    message = msg.match[4] || ""
    robot.logger.info "#{msg.envelope.user.name} acked #{host}"
    call = "cmd.cgi"
    data = "cmd_typ=33&host=#{host}&cmd_mod=2&sticky_ack=on&com_author=#{msg.envelope.user}&send_notification=on&com_data=#{encodeURIComponent(message)}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Your acknowledgement was received by nagios"

  robot.respond /nagios ack(nowledge)? (\S+):(.+) (.*)/i, (msg) ->
    host = msg.match[2]
    service = msg.match[3].replace / +/g, "+" # Spaces in service names must be replaced with a '+' to post the command
    message = msg.match[4] || ""
    robot.logger.info "#{msg.envelope.user.name} acked #{host}:#{service}"
    call = "cmd.cgi"
    data = "cmd_typ=34&host=#{host}&service=#{service}&cmd_mod=2&sticky_ack=on&com_author=#{msg.envelope.user}&send_notification=on&com_data=#{encodeURIComponent(message)}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Your acknowledgement was received by nagios"

  robot.respond /nagios (down|downtime) ([^:\s]+) (\d[wdhm]+) (.*)/i, (msg) ->
    host = msg.match[2]
    duration = msg.match[3] || 30
    message = msg.match[4] || ""
    minutes = parsetime(duration) || 30
    downstart = new Date()
    downstop  = new Date(downstart.getTime() + (1000 * 60 * minutes))
    downstart_str = "#{downstart.getMonth()+1}-#{downstart.getDate()}-#{downstart.getFullYear()} #{downstart.getHours()}:#{downstart.getMinutes()}:#{downstart.getSeconds()}"
    downstop_str = "#{downstop.getMonth()+1}-#{downstop.getDate()}-#{downstop.getFullYear()} #{downstop.getHours()}:#{downstop.getMinutes()}:#{downstop.getSeconds()}"
    robot.logger.info "#{msg.envelope.user.name} scheduled downtime for #{host} for #{minutes}min from #{downstart_str} to #{downstop_str} b/c #{message}"
    call = "cmd.cgi"
    data = "cmd_typ=55&cmd_mod=2&host=#{host}&fixed=1&start_time=#{downstart_str}&end_time=#{downstop_str}&com_data=#{encodeURIComponent(message)}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Downtime for #{host} for #{minutes}m"

  robot.respond /nagios (down|downtime) (\S+):(\S+) (\d+[wdhm]?) (.*)/i, (msg) ->
    host = msg.match[2]
    service = msg.match[3]
    duration = msg.match[4] || 30
    message = msg.match[5] || ""
    downstart = new Date()
    minutes = parsetime(duration)
    downstop  = new Date(downstart.getTime() + (1000 * 60 * minutes))
    downstart_str = "#{downstart.getMonth()+1}-#{downstart.getDate()}-#{downstart.getFullYear()} #{downstart.getHours()}:#{downstart.getMinutes()}:#{downstart.getSeconds()}"
    downstop_str = "#{downstop.getMonth()+1}-#{downstop.getDate()}-#{downstop.getFullYear()} #{downstop.getHours()}:#{downstop.getMinutes()}:#{downstop.getSeconds()}"
    robot.logger.info "#{msg.envelope.user.name} scheduled downtime for #{host}:#{service} for #{minutes}min from #{downstart_str} to #{downstop_str} b/c #{message}"
    call = "cmd.cgi"
    data = "cmd_typ=56&cmd_mod=2&host=#{host}&service=#{service}&fixed=1&start_time=#{downstart_str}&end_time=#{downstop_str}&com_data=#{encodeURIComponent(message)}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Downtime for #{host}:#{service} for #{minutes}m"

  robot.respond /nagios mute (\S+):(\S+) (\d+)/i, (msg) ->
    host = msg.match[1]
    service = msg.match[2]
    minutes = msg.match[3] || 30
    robot.logger.info "#{msg.envelope.user.name} asked to mute #{host}:#{service}"
    call = "cmd.cgi"
    data = "cmd_typ=9&cmd_mod=2&host=#{host}&service=#{service}&not_dly=#{minutes}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Muting #{host}:#{service} for #{minutes}m"

  robot.respond /nagios recheck (\S+):(\S+)/i, (msg) ->
    host = msg.match[1]
    service = msg.match[2]
    robot.logger.info "#{msg.envelope.user.name} forced recheck of #{host}:#{service}"
    call = "cmd.cgi"
    d = new Date()
    start_time = "#{d.getMonth()+1}-#{d.getDate()}-#{d.getFullYear()} #{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}"
    data = "cmd_typ=7&cmd_mod=2&host=#{host}&service=#{service}&force_check=on&start_time=#{start_time}"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Scheduled to recheck #{host}:#{service} at #{start_time}"

  robot.respond /nagios (all_alerts_off|stfu|shut up)/i, (msg) ->
    robot.logger.info "#{msg.envelope.user.name} disable notifications"
    call = "cmd.cgi"
    data = "cmd_typ=11&cmd_mod=2"
    nagios_post msg, call, data, (res) ->
      if res.match(/Your command request was successfully submitted to Nagios for processing/)
        msg.send "Ok, all alerts off. (this disables ALL alerts, not just mine.)"

  robot.respond /nagios all_alerts_on/i, (msg) ->
    robot.logger.info "#{msg.envelope.user.name} enabled notifications"
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

