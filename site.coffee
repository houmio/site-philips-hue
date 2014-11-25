WebSocket = require('ws')
winston = require('winston')
hue = require("node-hue-api")

winston.remove(winston.transports.Console)
winston.add(winston.transports.Console, { timestamp: ( -> new Date() ) })
console.log = winston.info

houmioServer = process.env.HORSELIGHTS_SERVER || "ws://localhost:3000"
houmioSitekey = process.env.HORSELIGHTS_SITEKEY || "devsite"
hueIp = process.env.HORSELIGHTS_PHILIPS_HUE_IP || "localhost"
hueUsername = process.env.HORSELIGHTS_PHILIPS_HUE_USERNAME || "developer"

console.log "Using HORSELIGHTS_SERVER=#{houmioServer}"
console.log "Using HORSELIGHTS_SITEKEY=#{houmioSitekey}"
console.log "Using HORSELIGHTS_PHILIPS_HUE_IP=#{hueIp}"
console.log "Using HORSELIGHTS_PHILIPS_HUE_USERNAME=#{hueUsername}"

exit = (msg) ->
  console.log msg
  process.exit 1

socket = null
pingId = null

displayResult = (result) ->
  console.log JSON.stringify(result, null, 2)

displayError = (err) ->
  console.error err

HueApi = hue.HueApi
lightState = hue.lightState
api = new HueApi(hueIp, hueUsername);
api.connect().then(displayResult).done();

onSocketOpen = ->
  console.log "Connected to #{houmioServer}"
  pingId = setInterval ( -> socket.ping(null, {}, false) ), 3000
  publish = JSON.stringify { command: "publish", data: { sitekey: houmioSitekey, vendor: "philips-hue" } }
  socket.send(publish)
  console.log "Sent message:", publish

onSocketClose = ->
  clearInterval pingId
  exit "Disconnected from #{houmioServer}"

scaleByteToPercent = (oldValue) ->
  oldMin = 0
  oldMax = 255
  newMin = 0
  newMax = 100
  Math.floor (((oldValue - oldMin) * (newMax - newMin)) / (oldMax - oldMin)) + newMin

scaleByteTo359 = (oldValue) ->
  oldMin = 0
  oldMax = 255
  newMin = 0
  newMax = 359
  Math.floor (((oldValue - oldMin) * (newMax - newMin)) / (oldMax - oldMin)) + newMin

onSocketMessage = (s) ->
  msg = JSON.parse s
  state = lightState.create()
  if msg.data.on then state.on() else state.off()
  if msg.data.on then state.brightness(scaleByteToPercent(msg.data.bri))
  if msg.data.hue and msg.data.saturation then state.hsl(scaleByteTo359(msg.data.hue), scaleByteToPercent(msg.data.saturation), scaleByteToPercent(msg.data.bri))
  api.setLightState(msg.data.devaddr, state)
    .then(displayResult)
    .fail(displayError)
    .done()

transmitToServer = (data) ->
  socket.send JSON.stringify { command: "generaldata", data: data }

socketPong = () ->
  socket.pong()

socket = new WebSocket(houmioServer)
socket.on 'open', onSocketOpen
socket.on 'close', onSocketClose
socket.on 'error', exit
socket.on 'ping', socketPong
socket.on 'message', onSocketMessage