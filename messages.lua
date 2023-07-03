local buttons = require 'modules/touchpoint'
local JSON = require 'modules/json'
local strings = require "cc.strings"
local pretty = require 'cc.pretty'
local client = {}
local width, height = term.getSize()

function getDiscord(path, headers)
    local url = client.createApiUrl(path)
    if not headers then
        headers = {}
    end
    headers['Authorization'] = client.token
    local response = http.get(url, headers)
    return JSON:decode(response.readAll())
end
function postDiscord(path, body, headers)
    local url = client.createApiUrl(path)
    if not headers then
        headers = {}
    end
    headers['Content-Type'] = 'application/json'
    headers['Authorization'] = client.token
    local response = http.post(url, body, headers)
    if not response then
        return nil
    end
    return JSON:decode(response.readAll())
end
function safeReplace(text, match, replacement)
    -- sanitize the living shit out of the matcher
    match = string.gsub(match, '%(', '%(')
    match = string.gsub(match, '%)', '%)')
    match = string.gsub(match, '%%', '%%')
    match = string.gsub(match, '%[', '%[')
    match = string.gsub(match, '%]', '%]')
    match = string.gsub(match, '%*', '%*')
    match = string.gsub(match, '%+', '%+')
    match = string.gsub(match, '%-', '%-')
    match = string.gsub(match, '%?', '%?')
    match = string.gsub(match, '%.', '%.')
    match = string.gsub(match, '%|', '%|')
    match = string.gsub(match, '%^', '%^')
    match = string.gsub(match, '%$', '%$')
    
    -- then make the actual replacment
    return string.gsub(text, match, replacement)
end
function convertTableToSet(t)
    local set = {}
    for i,v in pairs(t) do
        set[v] = i
    end
    return set
end

local button = nil
local gui = nil
local messages = {}
local channels = {}
local channelSet = {}
local channelListScroll = 1
local guilds = {}
local guildSet = {}
local guildListScroll = 1
local members = {}
local roles = {}
local roleSet = {}
local user = {}
local member = {}
local open = {
    menu = 'messages',
    guild = '1033551490331197462',
    channel = '1124567075881500772'
}
local shiftDown = false
local capsLock = false
local textVisualWindow = 1
local maxTextBoxHeight = 5
local textBox = ''
local textCursorX = 0
local textCursorY = 0
local textBoxLines = {
    ''
}
local whiteSpace = string.rep(' ', width - 2)
local textCursorIndex = 0

function renderGuilds()
    gui:clear()
    term.setCursorBlink(false)
    for i = guildListScroll, #guilds do
        if (i - guildListScroll) >= height then
            break
        end
        local name = guilds[i].name
        button(name, 1, i - guildListScroll, #name, 1, guilds[i].id)
    end
    gui:draw()
end
function renderChannels()
    gui:clear()
    term.setCursorBlink(false)
    term.clear()
    button('<', 1, 1, 1, height)
    local buttonY = 1
    for i = channelListScroll, #channels do
        if buttonY > height then
            break
        end
        local channel = channels[i]
        if channel.type == 0 or channel.type == 1 or channel.type == 3 or channel.type == 5 then
            local name = '#' .. channel.name
            button(name, 3, buttonY, #name + 3 -1, 1, channels[i].id)
            buttonY = buttonY +1
        elseif channel.type == 4 then
            term.setCursorPos(2, buttonY)
            term.write(channel.name .. ':')
            buttonY = buttonY +1
        end
    end
    gui:draw()
end


local function clampCursor()
    textBoxLines = strings.wrap(textBox, width-2)
    textCursorX = math.max(textCursorX, 0)
    textCursorX = math.min(textCursorX, #textBox)
    textCursorY = math.max(textCursorY, 1)
    textCursorY = math.min(textCursorY, #textBoxLines)
    if textCursorY > textVisualWindow + maxTextBoxHeight then
        textVisualWindow = textVisualWindow +1
    elseif textCursorY < textVisualWindow then
        textVisualWindow = textVisualWindow -1
    end
    textCursorIndex = textCursorX + ((textCursorY - 1) * #whiteSpace)
end

local function inputText(text)
    local left = string.sub(textBox, 1, textCursorIndex)
    local right = string.sub(textBox, textCursorIndex + 1, #textBox)
    textBox = left .. text .. right
    textCursorX = textCursorX + #text
    local lines = #strings.wrap(text)
    textCursorY = textCursorY + (lines - 1)
    clampCursor()
end

function getMember(id)
    local member = {}
    if not members[id] then
        member = getDiscord('/guilds/' .. open.guild .. '/members/' .. id)
        members[id] = member
    else
        member = members[id]
    end
    return member
end

function checkMentionsMyself(message) 
    local myRoles = convertTableToSet(member)
    local mentionsMyRoles = false
    local mentionsMe = false
    for _,v in pairs(message.mentions) do
        if v.id == user.id then
            mentionsMe = true
            break
        end
    end
    for _,v in pairs(message.mention_roles) do
        if myRoles[v] then 
            mentionsMyRoles = true 
            break
        end
    end
    return message.mention_everyone or mentionsMe or mentionsMyRoles
end

function processMessage(info, background)
    local username = info.member.nick or info.author.global_name
    local lines = strings.wrap(info.content, (width - 4) - #username)
    local content = ''
    local textBlit = {}
    local backgroundBlit = {}
    local mentionIds = {}
    for _,v in pairs(info.mentions) do
        if v.id then
            v.member = getMember(v.id)
        end

        mentionIds[v.id] = v.member.nick or v.global_name
    end
    local black = checkMentionsMyself(info) and colors.toBlit(colors.orange) or colors.toBlit(colors.black)
    if background then
        black = colors.toBlit(background)
    end
    local white = colors.toBlit(colors.white)
    local blue = colors.toBlit(colors.blue)
    for i,l in pairs(lines) do
        textBlit[i] = ''
        backgroundBlit[i] = ''
        for name,id in l:gmatch('<(a?:[0-9a-zA-Z_]-:)(%d-)>') do
            l = safeReplace(l, '<' .. name .. id .. '>', name)
        end
        local lastIndex = 1
        for id in l:gmatch('<@([0-9]-)>') do
            local index = string.find(l, '<@([0-9]-)>')
            l = safeReplace(l, '<@' .. id .. '>', '@' .. mentionIds[id])
            local space = string.rep(black, index - lastIndex)
            local color = string.rep(blue, #mentionIds[id] + 1)
            backgroundBlit[i] = backgroundBlit[i] .. color
        end
        textBlit[i] = textBlit[i] .. string.rep(white, #l - #textBlit[i])
        backgroundBlit[i] = backgroundBlit[i] .. string.rep(black, #l - #backgroundBlit[i])
        content = content .. '\n' .. l
    end
    if #info.attachments > 0 then
        local attachments = ''
        if #info.attachments == 1 then
            attachments = info.attachments[1].filename
        else
            for i,v in pairs(info.attachments) do
                attachments = attachments .. v.filename .. ', '
            end
        end
        attachments = 'files: ' .. attachments
        -- fill in the stuff with empty space since files dont ask for more then white
        for i,l in pairs(strings.wrap(attachments, (width - 4) - #username)) do
            textBlit[#lines + i] = string.rep(white, #l)
            backgroundBlit[#lines + i] = string.rep(black, #l)
        end
        content = content .. '\n' .. attachments
    end
    return string.sub(content, 2), textBlit, backgroundBlit
end
function clearMessages()
    local width, height = term.getSize()
    local clearer = string.rep(' ', width-(#textBoxLines + 1))
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    for i = 1, height - 2 do
        term.setCursorPos(2, i)
        term.write(clearer)
    end
end
function renderMessages()
    if open.menu == 'messages' then
        clearMessages()
        local i = height - #textBoxLines
        for m,v in pairs(messages) do
            local content = strings.wrap(v.content, (width - 4) - #v.user.display)
            local nextAuthor = messages[m+1] and messages[m+1].user.id or ''
            local spaceFill = string.rep(' ', #v.user.display +2)
            if nextAuthor ~= v.user.id then
                term.setBackgroundColor(colors.black)
                term.setCursorPos(2, i - #content)
                term.setTextColor(v.user.roleColor)
                term.write(v.user.display)
                term.setTextColor(colors.white)
                term.write(': ')
            end
            if v.mentionsMe then
                term.setBackgroundColor(colors.orange)
            end
            for l = 1, #content do
                term.setCursorPos(#v.user.display + 4, (l - 1) + (i - #content))
                term.blit(content[l], v.textBlit[l], v.backgroundBlit[l])
            end
            i = i -#content
            if i <= 1 then
                break
            end
        end
        term.setBackgroundColor(colors.gray)
        for l = textVisualWindow, #textBoxLines do
            if l - maxTextBoxHeight > maxTextBoxHeight then
                break
            end
            term.setCursorPos(2, (height - math.min(#textBoxLines, maxTextBoxHeight + 1)) + l)
            term.write(whiteSpace)
            term.setCursorPos(2, (height - math.min(#textBoxLines, maxTextBoxHeight + 1)) + l)
            term.write(textBoxLines[l])
        end
        term.setCursorBlink(true)
        term.setCursorPos(math.max(math.min(textCursorX, #whiteSpace - 1), 0) + 2, (height - math.min(#textBoxLines, maxTextBoxHeight + 1)) + textCursorY)
        term.setBackgroundColor(colors.black)
    end
end
function bumpMessages()
    local oldMessages = {table.unpack(messages)}
    for i,v in pairs(oldMessages) do
        if i+1 > height then
            break
        end
        messages[i+1] = v
    end
end
function makeRoleSet()
    for index,role in pairs(roles) do
        roleSet[role.id] = index
    end
end
function findTopRole(roleList)
    local topRoleIndex = 0
    local topRoleId = ''
    for _,id in pairs(roleList) do
        local index = roleSet[id]
        if index > topRoleIndex then
            topRoleIndex = index
            topRoleId = id
        end
    end
    return roles[roleSet[topRoleId]]
end
function stripMessageData(data)
    local topRole = findTopRole(data.member.roles)
    local roleColor = topRole and topRole.color or colors.white
    local roundedColor = math.pow(2, tonumber(colors.toBlit(roleColor), 16))
    local content, textBlit, backBlit = processMessage(data)
    return {
        id = data.id,
        user = {
            display = data.member.nick or data.author.global_name,
            id = data.author.id,
            roleColor = math.max(roundedColor, 1)
        },
        mentionsMe = checkMentionsMyself(data),
        content = content,
        textBlit = textBlit,
        backgroundBlit = backBlit
    }
end
function storeMessage(data)
    bumpMessages()
    messages[1] = stripMessageData(data)
end
function createMessage(content)
    local message = JSON:encode({
        content = content
    })
    local res = postDiscord('/channels/' .. open.channel .. '/messages', message)
    if not res then
        storeMessage({
            content = content,
            attachments = {},
            member = member,
            author = user,
            mentions = {},
            mention_roles = {},
            mention_everyone = false
        })
        renderMessages()
    end
end
function updateMessages()
    local discordMessages = getDiscord('/channels/' .. open.channel .. '/messages?limit=' .. height)
    for i,v in pairs(discordMessages) do
        v.guild_id = open.guild
        v.member = getMember(v.author.id)
        messages[i] = stripMessageData(v)
    end
    renderMessages()
end

function eventHandler(e, data)
    if e == 'READY' then
        term.setCursorPos(1, 1)
        user = data.discordData.user
        client = data.client
        gui = data.gui
        button = data.buttonCreator
        member = getDiscord('/guilds/' .. open.guild .. '/members/' .. user.id)
        roles = getDiscord('/guilds/' .. open.guild .. '/roles')
        local discordChannels = getDiscord('/guilds/' .. open.guild .. '/channels')
        guilds = getDiscord('/users/@me/guilds')
        for i,v in pairs(guilds) do
            guildSet[v.id] = i
        end
        makeRoleSet()
        updateMessages()
        term.setCursorBlink(true)
        term.setCursorPos(2, height)
        term.setBackgroundColor(colors.gray)
        term.write(whiteSpace)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, height)

        button('<', 1, 1, 1, height)
        gui:draw()
    elseif e == 'MESSAGE_CREATE' then
        if data.guild_id == open.guild and data.channel_id == open.channel then
            storeMessage(data)
            renderMessages()
        end
    elseif e == 'MESSAGE_UPDATE' then
        if data.guild_id == open.guild and data.channel_id == open.channel then
            for i,v in pairs(messages) do
                if v.id == data.id and data.content then
                    messages[i].content = data.content
                    renderMessages()
                    break
                end
            end
        end
    elseif e == 'key' then
        local key = keys.getName(data[2])
        if key == 'left' then
            textCursorX = textCursorX -1
            clampCursor()
        elseif key == 'right' then
            textCursorX = textCursorX +1
            clampCursor()
        elseif key == 'enter' then
            if shiftDown then
                inputText('\n')
                renderMessages()
            else
                createMessage(textBox)
                textBox = ''
                textVisualWindow = 0
                textCursorX = 0
                term.setCursorPos(2, height)
                term.setBackgroundColor(colors.gray)
                term.write(whiteSpace)
                term.setBackgroundColor(colors.black)
                clampCursor()
                renderMessages()
            end
        elseif key == 'leftShift' or key == 'rightShift' then
            shiftDown = true
        elseif key == 'backspace' then
            local left = string.sub(textBox, 1, textCursorIndex - 1)
            local right = string.sub(textBox, textCursorIndex + 1, #textBox)
            textBox = left .. right
            if string.sub(textBox, textCursorIndex - 1, textCursorIndex) == '\n' then
                textCursorY = textCursorY -1
                textCursorX = #textBoxLines[textCursorY]
            else
                textCursorX = textCursorX -1
            end
            clampCursor()
            inputText('')
            renderMessages()
        end
    elseif e == 'char' then
        inputText(data[2])
        renderMessages()
    elseif e == 'key_up' then
        local key = keys.getName(data[2])
        if key == 'leftShift' or key == 'rightShift' then
            shiftDown = false
        end
    elseif e == 'button_click' then
        gui:flash(data[2])
        if data[2] == '<' and open.menu == 'messages' then
            open.menu = 'channels'
            term.clear()
            renderChannels()
            gui:draw()
        elseif data[2] == '<' and open.menu == 'channels' then
            open.menu = 'guilds'
            term.clear()
            gui:draw()
        elseif open.menu == 'channels' then
            open.channel = data[2]
            open.menu = 'messages'
            term.clear()
            updateMessages()
        end
    elseif e == 'paste' then
        inputText(data[2], selected)
        renderMessages()
    elseif e == 'mouse_scroll' then
        if open.menu == 'channels' then
            channelListScroll = math.max(channelListScroll + data[2], 1)
            renderChannels()
        elseif open.menu == 'guilds' then
            guildListScroll = math.max(guildListScroll + data[2], 1)
            renderGuilds()
        end
    end
end

return eventHandler