local buttons = require 'modules/touchpoint'
local JSON = require 'modules/json'
local strings = require "cc.strings"
local pretty = require 'cc.pretty'
local client = {}
local width, height = term.getSize()
function trim(s) 
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
function Split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

local colorCodes = {
    [colors.white] = 0xF0F0F0,
    [colors.orange] = 0xF2B233,
    [colors.magenta] = 0xE57FD8,
    [colors.lightBlue] = 0x99B2F2,
    [colors.yellow] = 0xDEDE6C,
    [colors.lime] = 0x7FCC19,
    [colors.pink] = 0xF2B2CC,
    [colors.gray] = 0x4C4C4C,
    [colors.lightGray] = 0x999999,
    [colors.cyan] = 0x4C99B2,
    [colors.purple] = 0xB266E5,
    [colors.blue] = 0x3366CC,
    [colors.brown] = 0x7F664C,
    [colors.green] = 0x57A64E,
    [colors.red] = 0xCC4C4C,
}
function nearestValue(number)
    local smallestSoFar, colorValue
    for k,v in pairs(colorCodes) do
        if not smallestSoFar or (math.abs(number-v) < smallestSoFar) then
            smallestSoFar = math.abs(number-v)
            colorValue = k
        end
    end
    return colorValue
end
function getDiscord(path, headers)
    local url = client.createApiUrl(path)
    if not headers then
        headers = {}
    end
    headers['Authorization'] = client.token
    local response = http.get(url, headers)
    if not response then
        return nil
    end
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
    match = match:gsub('%(', '%%(')
    match = match:gsub('%)', '%%)')
    match = match:gsub('%%', '%%%')
    match = match:gsub('%[', '%%[')
    match = match:gsub('%]', '%%]')
    match = match:gsub('%*', '%%*')
    match = match:gsub('%+', '%%+')
    match = match:gsub('%-', '%%-')
    match = match:gsub('%?', '%%?')
    match = match:gsub('%.', '%%%.')
    match = match:gsub('%|', '%%|')
    match = match:gsub('%^', '%%^')
    match = match:gsub('%$', '%%$')
    
    -- then make the actual replacment
    return text:gsub(match, replacement)
end
function convertTableToSet(t)
    local set = {}
    for i,v in pairs(t) do
        set[v] = i
    end
    return set
end

-- might bring back buttons but for now these buttons are completely unused XD
local button = nil
local gui = nil
local guilds = {}
local guildSet = {}
local user = {}
local member = {}
local open = {
    menu = 'messages',
    guild = '1033551490331197462',
    channel = '1038236110335266907'
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
    if #textBox + #text > 2000 then
        return
    end
    local left = string.sub(textBox, 1, textCursorIndex)
    local right = string.sub(textBox, textCursorIndex + 1, #textBox)
    textBox = left .. text .. right
    textCursorX = textCursorX + #text
    local lines = #strings.wrap(text)
    textCursorY = textCursorY + (lines - 1)
    clampCursor()
    guilds[open.guild].channels[open.channel].msgProto = textBox
end

function getMember(id)
    local member = {}
    local members = guilds[open.guild].members
    if not members[id] then
        member = getDiscord('/guilds/' .. open.guild .. '/members/' .. id)
        -- discord says this member doesnt exists??????????????????????
        if not member then
            member = {
                roles = {}
            }
        end
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

function clampNameToMontitor(name)
    return math.min(#name, math.floor(width / 3) + 2)
end
function processMessage(info, background)
    local username = info.member.nick or info.author.global_name or info.author.username
    local black = checkMentionsMyself(info) and colors.orange or colors.black
    if background then
        black = background
    end
    if info.failed then
        black = colors.red
    end
    if info.loading then
        black = colors.lightGray
    end
    black = colors.toBlit(black)
    local white = colors.toBlit(colors.white)
    local blue = colors.toBlit(colors.blue)
    local darkGrey = colors.toBlit(colors.gray)
    local channels = guilds[open.guild].channels
    local content = info.content
    if #info.attachments > 0 then
        content = content .. '\nfiles: \n'
        if #info.attachments == 1 then
            content = content .. info.attachments[1].filename
        else
            for i,v in pairs(info.attachments) do
                content = content .. v.filename .. ', '
            end
        end
    end
    local textBlit = string.rep(white, #content)
    local backgroundBlit = string.rep(black, #content)
    for name,id in content:gmatch('<(a?:[0-9a-zA-Z_]-:)(%d-)>') do
        local index = content:find('<(a?:[0-9a-zA-Z_]-:)(%d-)>')
        content = safeReplace(content, '<' .. name .. id .. '>', name)
        local bcolor = string.rep(blue, #name)
        backgroundBlit = backgroundBlit:sub(0, index - 1) .. bcolor .. backgroundBlit:sub(#bcolor, #backgroundBlit)
    end
    for id in content:gmatch('<@([0-9]-)>') do
        local index = content:find('<@([0-9]-)>')
        local member = getMember(id)
        local display = member.nick or member.user.global_name or member.user.username
        content = safeReplace(content, '<@' .. id .. '>', '@' .. display)
        local color = string.rep(blue, #display + 1)
        backgroundBlit = backgroundBlit:sub(0, index) .. color .. backgroundBlit:sub(#color, #backgroundBlit)
    end
    for id in content:gmatch('<#([0-9]-)>') do
        local index = content:find('<#([0-9]-)>')
        content = safeReplace(content, '<#' .. id .. '>', '#' .. channels[id].name)
        local color = string.rep(blue, #channels[id].name + 1)
        backgroundBlit = backgroundBlit:sub(0, index) .. color .. backgroundBlit:sub(#color, #backgroundBlit)
    end
    for content in content:gmatch('`(.-)`') do
        local index = content:find('`(.-)`')
        content = safeReplace(content, '`' .. content .. '`', content)
        local color = string.rep(darkGrey, #content)
        backgroundBlit = backgroundBlit:sub(0, index) .. color .. backgroundBlit:sub(#color, #backgroundBlit)
    end
    
    local width = (width - clampNameToMontitor(username)) - 4
    local tBlit = {}
    local bBlit = {}
    -- copied from jarj because your mom
    local lines, lines_n, current_line = {}, 0, ""
    local curTBlit = ''
    local curBBlit = ''
    local function push_line()
        sleep(0)
        lines_n = lines_n + 1
        lines[lines_n] = current_line
        tBlit[lines_n] = curTBlit
        bBlit[lines_n] = curBBlit
        current_line = ""
        curTBlit = ''
        curBBlit = ''
    end

    local pos, length = 1, #content
    local sub, match = string.sub, string.match
    print(width)
    while pos <= length do
        print(pos)
        local head = sub(content, pos, pos)
        if head == " " or head == "\t" then
            local whitespace = match(content, "^[ \t]+", pos)
            current_line = current_line .. whitespace
            curTBlit = curTBlit .. textBlit:sub(pos, #whitespace)
            curBBlit = curBBlit .. backgroundBlit:sub(pos, #whitespace)
            pos = pos + #whitespace
        elseif head == "\n" then
            push_line()
            pos = pos + 1
        else
            local word = match(content, "^[^ \t\n]+", pos)
            -- this is for the blit's since the HAVE to have where the word started
            local start = pos
            pos = pos + #word
            if #word > width then
                -- Print a multiline word
                while #word > 0 do
                    local space_remaining = width - #current_line - 1
                    if space_remaining <= 0 then
                        push_line()
                        space_remaining = width
                    end

                    current_line = current_line .. sub(word, 1, space_remaining)
                    curTBlit = curTBlit .. textBlit:sub(start, #word - space_remaining)
                    curBBlit = curBBlit .. backgroundBlit:sub(start, #word - space_remaining)
                    word = sub(word, space_remaining + 1)
                end
            else
                -- Print a word normally
                if width - #current_line < #word then push_line() end
                current_line = current_line .. word
                curTBlit = curTBlit .. textBlit:sub(pos, #word)
                curBBlit = curBBlit .. backgroundBlit:sub(pos, #word)
            end
        end
    end

    push_line()

    -- Trim whitespace longer than width.
    for k, line in pairs(lines) do
        line = line:sub(1, width)
        tBlit[k] = textBlit:sub(1, width)
        bBlit[k] = backgroundBlit:sub(1, width)
        lines[k] = line
    end
    return lines, tBlit, bBlit
end
function renderMessages()
    if open.menu == 'messages' then
        term.clear()
        local i = height - #textBoxLines
        local messages = guilds[open.guild].channels[open.channel].messages
        for m,v in pairs(messages) do
            local nextAuthor = messages[m+1] and messages[m+1].user.id or ''
            if nextAuthor ~= v.user.id then
                term.setBackgroundColor(colors.black)
                term.setCursorPos(2, i - #v.content)
                term.setTextColor(v.user.roleColor)
                term.setBackgroundColor(colors.black)
                local name = v.user.display
                if #name > math.floor(width / 3) - 2 then
                    name = name:sub(0, math.floor(width / 3) - 2)
                    name = name .. ' ...'
                end
                term.write(name)
                term.setTextColor(colors.white)
                term.write(': ')
            end
            if v.mentionsMe then
                term.setBackgroundColor(colors.orange)
            end
            for l = 1, #v.content do
                term.setCursorPos(clampNameToMontitor(v.user.display) + 4, (l - 1) + (i - #v.content))
                if not v.textBlit[l] then
                    v.textBlit[l] = ''
                end
                if not v.backgroundBlit[l] then
                    v.backgroundBlit[l] = ''
                end
                if #v.textBlit[l] < #v.content[l] then
                    v.textBlit[l] = v.textBlit[l] .. string.rep(colors.toBlit(colors.white), #v.content[l] - #v.textBlit[l])
                elseif #v.textBlit[l] > #v.content[l] then
                    v.textBlit[l] = v.textBlit[l]:sub(0, #v.content[l])
                end
                if #v.backgroundBlit[l] < #v.content[l] then
                    v.backgroundBlit[l] = v.backgroundBlit[l] .. string.rep(colors.toBlit(colors.black), #v.content[l] - #v.backgroundBlit[l])
                elseif #v.backgroundBlit[l] > #v.content[l] then
                    v.backgroundBlit[l] = v.backgroundBlit[l]:sub(0, #v.content[l])
                end
                term.blit(v.content[l], v.textBlit[l], v.backgroundBlit[l])
            end
            i = i -#v.content
            if i <= 1 then
                break
            end
        end
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(2, 1)
        term.write(whiteSpace)
        term.setCursorPos(2, 1)
        local channelName = guilds[open.guild].channels[open.channel].name
        term.write(channelName)
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
    local messages = guilds[open.guild].channels[open.channel].messages
    local oldMessages = {table.unpack(messages)}
    for i,v in pairs(oldMessages) do
        if i+1 > height then
            break
        end
        messages[i+1] = v
    end
end
function findTopRole(roleList)
    local roles = guilds[open.guild].roles
    local topRolePosition = 0
    local topRoleId = ''
    for _,id in pairs(roleList) do
        local position = roles[id].position
        if position > topRolePosition then
            topRolePosition = position
            topRoleId = id
        end
    end
    return roles[topRoleId]
end
function stripMessageData(data)
    local roleColor
    local mentionsMe
    if data.author == 'system' then
        roleColor = 0x3366CC
        mentionsMe = true
        data.author = {
            username = 'App Message'
        }
        data.member = {}
    else
        local topRole = findTopRole(data.member.roles)
        roleColor = topRole and topRole.color or colors.white
        mentionsMe = checkMentionsMyself(data)
    end
    local content, textBlit, backBlit = processMessage(data)
    return {
        id = data.id,
        user = {
            display = data.member.nick or data.author.global_name or data.author.username,
            id = data.author.id,
            roleColor = nearestValue(roleColor)
        },
        mentionsMe = mentionsMe,
        content = content,
        textBlit = textBlit,
        backgroundBlit = backBlit
    }
end
function storeMessage(data)
    local messages = guilds[open.guild].channels[open.channel].messages
    bumpMessages()
    messages[1] = stripMessageData(data)
end
function editMessage(id, data) 
    local messages = guilds[open.guild].channels[open.channel].messages
    for i,v in pairs(messages) do
        if v.id == id then
            local content, textBlit, backBlit = processMessage(data)
            messages[i].mentionsMe = checkMentionsMyself(data)
            messages[i].content = content
            messages[i].textBlit = textBlit
            messages[i].backgroundBlit = backBlit
            renderMessages()
            break
        end
    end
end
function deleteMessage(id)
    local messages = guilds[open.guild].channels[open.channel].messages
    local oldMessages = {table.unpack(messages)}
    local isShifting = false
    for i,v in pairs(oldMessages) do
        if v.id == id then
            isShifting = true
        end
        if isShifting then
            messages[i] = messages[i+1]
        end
    end
end
local loadingId = 0
function createMessage(content, system)
    if system then 
        storeMessage({
            content = content,
            attachments = {},
            author = 'system',
            mentions = {},
            mention_roles = {},
            mention_everyone = false,
            failed = false,
            loading = true,
            -- use loading id so system messages and loading messages never conflict
            id = loadingId
        })
        loadingId = loadingId +1
        renderMessages()
        return
    end

    if content:sub(0, 1):find('%s') ~= nil or content:sub(-2, -1):find('%s') ~= nil then
        content = trim(content)
        if content:len() == 0 then
            return
        end
    end
    local curLoadId = loadingId
    storeMessage({
        content = content,
        attachments = {},
        member = getMember(user.id),
        author = user,
        mentions = {},
        mention_roles = {},
        mention_everyone = false,
        failed = false,
        loading = true,
        id = curLoadId
    })
    loadingId = loadingId +1
    renderMessages()

    local message = JSON:encode({
        content = content
    })
    local res = postDiscord('/channels/' .. open.channel .. '/messages', message)
    if not res then 
        res = {
            content = content,
            attachments = {},
            member = getMember(user.id),
            author = user,
            mentions = {},
            mention_roles = {},
            mention_everyone = false,
            failed = true,
            loading = false,
            id = curLoadId
        } 
        editMessage(curLoadId, res)
    else
        deleteMessage(curLoadId)
    end
    renderMessages()
end
function updateMessages()
    local discordMessages = getDiscord('/channels/' .. open.channel .. '/messages?limit=' .. height)
    if not discordMessages then
        storeMessage({
            failed = true,
            content = 'the content for this channel failed to load.\nyou might not have the permisions to read its contents',
            attachments = {},
            member = {},
            author = 'system',
            mentions = {},
            mention_roles = {},
            mention_everyone = false,
        })
    else
        local messages = guilds[open.guild].channels[open.channel].messages
        -- if we have messages already in the cache then dont try to get more
        if #messages > 0 then return end
        for i,v in pairs(discordMessages) do
            v.guild_id = open.guild
            v.member = getMember(v.author.id)
            messages[i] = stripMessageData(v)
        end
    end
    renderMessages()
end
function updateMembers()
    local members = getDiscord('guilds/'..open.guild..'/members')
    -- we cant exactly do anything about this other then prevent an error :/
    if not members then return end
    for i,v in pairs(members) do
        guilds[open.guild].members[v.id] = v
    end
end


function eventHandler(e, data)
    if e == 'READY' then
        term.setCursorPos(1, 1)
        user = data.discordData.user
        client = data.client
        guilds = {}
        for i,v in pairs(data.discordData.guilds) do
            local channels = v.channels
            v.channels = {}
            for ci,cv in pairs(channels) do
                cv.messages = {}
                cv.msgProto = ''
                v.channels[cv.id] = cv
            end
            v.channels.length = #channels
            v.members = {}
            local roles = v.roles
            v.roles = {}
            for ri,rv in pairs(roles) do
                v.roles[rv.id] = rv
            end
            guilds[v.id] = v
        end
        updateMembers()
        local member = getMember(user.id)
        local topRole = findTopRole(member.roles)
        local roleColor = topRole and topRole.color or colors.white
        user.messageProto = {
            display = member.nick or user.global_name or user.username,
            id = user.id,
            roleColor = nearestValue(roleColor)
        }

        updateMessages()
        term.setCursorBlink(true)
        term.setCursorPos(2, height)
        term.setBackgroundColor(colors.gray)
        term.write(whiteSpace)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, height)
    elseif e == 'MESSAGE_CREATE' then
        local messages = guilds[data.guild_id].channels[data.channel_id].messages
        -- dont add more messages until this channel has been handled
        if #messages > 0 then
            storeMessage(data)
            renderMessages()
        end
    elseif e == 'MESSAGE_UPDATE' then
        local messages = guilds[data.guild_id].channels[data.channel_id].messages
        -- there wont be the message we wish to edit in this channel if there are no messages
        if #messages > 0 then
            editMessage(data.id, data)
        end
    elseif e == 'key' then
        local key = keys.getName(data[2])
        if key == 'left' then
            textCursorX = textCursorX -1
            clampCursor()
            renderMessages()
        elseif key == 'right' then
            textCursorX = textCursorX +1
            clampCursor()
            renderMessages()
        elseif key == 'up' then
            textCursorY = textCursorY -1
            clampCursor()
            renderMessages()
        elseif key == 'down' then
            textCursorY = textCursorY +1
            clampCursor()
            renderMessages()
        elseif key == 'enter' then
            if shiftDown then
                inputText('\n')
                renderMessages()
            else
                local toSend = textBox
                textBox = ''
                textVisualWindow = 1
                textCursorX = 0
                clampCursor()
                renderMessages()
                if toSend:sub(0, 1) == '/' then
                    if toSend:find('/channels([ %d]-)') then
                        local channels = guilds[open.guild].channels
                        local page = tonumber(Split(toSend, ' ')[2])
                        if not page then page = 1 end
                        local list = ''
                        local idx = 1
                        local ended = false
                        for i,v in pairs(channels) do
                            if v.type == 0 or v.type == 1 or v.type == 3 or v.type == 5 then
                                if idx / (height - 3) >= page - 1 then
                                    if not (idx / (height - 3) < page) then
                                        list = list..'\npage '..page..'/'..math.floor(channels.length / (height - 3))
                                        ended = true
                                        break
                                    else
                                        local name = v.name
                                        if #name + 3 + 13 > (width - 1) - 23 then
                                            name = name:sub(0, (((width - 20) - 4) - 13) - 4)
                                            name = name .. ' ...'
                                        end
                                        list = list..'\n`'..name..'`:'..string.rep(' ', (((width - 20) - 4) - 13) - #name)..v.id
                                    end
                                end
                                idx = idx +1
                            end
                        end
                        -- list want filled to the max, so make it full to the max
                        if not ended then
                            list = list..'\npage '..page..'/'..math.floor(channels.length / (height - 3))
                        end
                        list = list:sub(2, #list)
                        createMessage(list, true)
                    elseif toSend:find('/move%-to .+') then
                        local channel = Split(toSend, ' ')[2]
                        if tonumber(channel) then
                            channel = channel
                        else
                            for k,v in pairs(guilds[open.guild].channels) do
                                if type(v) == 'table' then
                                    if v.name:find(channel) then
                                        channel = v.id
                                        break
                                    end
                                end
                            end
                        end
                        open.channel = channel
                        textBox = guilds[open.guild].channels[open.channel].msgProto
                        inputText('')
                        updateMembers()
                        updateMessages()
                        renderMessages()
                    else
                        createMessage('unknown command '..toSend, true)
                    end
                    return
                elseif toSend:sub(0, 2) == '\\/' then
                    toSend = toSend:sub(1, #toSend)
                end
                createMessage(toSend)
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