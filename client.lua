local pretty = require "cc.pretty"
local JSON = require 'modules/json'

math.randomseed(os.epoch("local"))

apiVersion = 10
gateway = 'wss://gateway.discord.gg?encoding=json&v=' .. apiVersion
intentNames = {
    [1] = GUILDS,
    [2] = GUILD_MEMBERS,
    [4] = GUILD_MODERATION,
    [8] = GUILD_EMOJIS_AND_STICKERS,
    [16] = GUILD_INTEGRATIONS,
    [32] = GUILD_WEBHOOKS,
    [64] = GUILD_INVITES,
    [128] = GUILD_VOICE_STATES,
    [256] = GUILD_PRESENCES,
    [512] = GUILD_MESSAGES,
    [1024] = GUILD_MESSAGE_REACTIONS,
    [2048] = GUILD_MESSAGE_TYPING,
    [4096] = DIRECT_MESSAGES,
    [8192] = DIRECT_MESSAGE_REACTIONS,
    [16384] = DIRECT_MESSAGE_TYPING,
    [32768] = MESSAGE_CONTENT,
    [65536] = GUILD_SCHEDULED_EVENTS,
    [131072] = AUTO_MODERATION_CONFIGURATION,
    [262144] = AUTO_MODERATION_EXECUTION,
    
    GUILDS = 1,
    GUILD_MEMBERS = 2,
    GUILD_MODERATION = 4,
    GUILD_EMOJIS_AND_STICKERS = 8,
    GUILD_INTEGRATIONS = 16,
    GUILD_WEBHOOKS = 32,
    GUILD_INVITES = 64,
    GUILD_VOICE_STATES = 128,
    GUILD_PRESENCES = 256,
    GUILD_MESSAGES = 512,
    GUILD_MESSAGE_REACTIONS = 1024,
    GUILD_MESSAGE_TYPING = 2048,
    DIRECT_MESSAGES = 4096,
    DIRECT_MESSAGE_REACTIONS = 8192,
    DIRECT_MESSAGE_TYPING = 16384,
    MESSAGE_CONTENT = 32768,
    GUILD_SCHEDULED_EVENTS = 65536,
    AUTO_MODERATION_CONFIGURATION = 131072,
    AUTO_MODERATION_EXECUTION = 262144    
}

function createIntents(intents)
    local parsedIntents = 0
    for i,v in pairs(intents) do
        parsedIntents = parsedIntents + (type(v) == 'number' and v or intentNames[v])
    end
    return parsedIntents
end

function createApiUrl(path, version)
    return 'https://discord.com/api/v' .. (version and version or apiVersion) .. path
end

function connectDiscord(userToken, intents, eventHandle)
    heartbeatInterval = 0
    heartbeatTimer = nil
    null = '__NULL__'

    ws = http.websocket(gateway)
    print('connecting...')

    function sendJson(table)
        local settings = {
            null = null,
            stringsAreUtf8 = true
        }
        local json = JSON:encode(table, nil, settings)
        ws.send(json)
    end

    function sendPing(imediatly)
        sendJson({
            op = 1,
            d = sequenceCode and sequenceCode or null
        })
    end

    function sendAuth()
        sendJson({
            op = 2,
            d = {
                token = userToken,
                capabilities = intents,
                properties = {
                    os = 'linux',
                    browser = "cctd",
                    device = 'cctd'
                }
            }
        })
    end

    buffer = ''

    repeat
        local eventData = {os.pullEvent()}
        local event = eventData[1]
        if event == 'websocket_message' and eventData[2] == gateway then
            -- MAJOR TODO
            -- this HAS to use zlib compression on the websocket messages.
            -- but atm i cant find any lua zlib inflators that dont use 
            -- something like lua jit or os.execute
            local messageData = textutils.unserialiseJSON(eventData[3])
            local file = fs.open('/debug/' .. (messageData.t and messageData.t or messageData.op) .. '.json', 'w')
            file.write(messageData.t == 'READY' and eventData[3] or JSON:encode(messageData, nil, { 
                pretty = true, 
                align_keys = false, 
                array_newline = true,
                indent = '    '  
            }))
            file.close()
            if messageData.op == 10 then
                messageData = messageData.d
                heartbeatInterval = messageData.heartbeat_interval / 1000
                heartbeatTimer = os.startTimer(heartbeatInterval)
                sendPing()
                sendAuth()
                print('connected and authorized...')
            elseif messageData.op == 1 then
                -- discord requested a ping
                sendPing()
            elseif messageData.op == 11 then
            elseif messageData.op == 0 then
                sequenceCode = messageData.s
                eventHandle(messageData.t, messageData.d)
            end
        elseif event == 'websocket_closed' then
            closedUrl = eventData[2]
            print('gateway closed with error ' .. (eventData[4] or 'unknown') .. ' ' .. eventData[3] and eventData[3])
        elseif event == 'timer' and eventData[2] == heartbeatTimer then
            heartbeatTimer = os.startTimer(heartbeatInterval)
            sendPing()
        end
    until gateway == closedUrl
end

return {
    createApiUrl = createApiUrl,
    createIntents = createIntents,
    connectDiscord = connectDiscord
}