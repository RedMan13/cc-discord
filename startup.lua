local buttons = require 'modules/touchpoint'
local client = require 'client'
local JSON = require 'modules/json'
local messageRendering = require 'messages'

term.clear()
local monWidth, monHeight = term.getSize()
local whiteSpace = string.rep(' ', monWidth - 2)
local gui = buttons.new()
local token = nil
local function button(label, x, y, w, h, id)
    gui:add(label, nil, x, y, (w -1) + x, (h -1) + y, colors.red, colors.lime, nil, nil, id)
end

keyMap = {
    apostrophe = '\'',
    comma = ',',
    minus = '-',
    period = '.',
    slash = '/',
    one = 1,
    two = 2,
    three = 3,
    four = 4,
    five = 5,
    six = 6,
    seven = 7,
    eight = 8,
    nine = 9,
    zero = 0,
    semicolon = ';',
    equals = '=',
    leftBracket = '[',
    backslash = '\\',
    rightBracket = ']',
    grave = '`',
    tab = '\t',

    APOSTROPHE = '"',
    COMMA = '<',
    MINUS = '_',
    PERIOD = '>',
    SLASH = '?',
    ONE = '!',
    TWO = '@',
    THREE = '#',
    FOUR = '$',
    FIVE = '%',
    SIX = '^',
    SEVEN = '&',
    EIGHT = '*',
    NINE = '(',
    ZERO = ')',
    SEMICOLON = ':',
    EQUALS = '+',
    LEFTBRACKET = '{',
    BACKSLASH = '|',
    RIGHTBRACKET = '}',
    GRAVE = '~',
    TAB = '\t',
}

if not fs.exists('/credentials.txt') then
    local attemptLogin
    local function attemptLogin(failed, message, nameMessage, passwordMessage)
        local name = ''
        local password = ''
        local nameCursor = 0
        local passwordCursor = 0
        local nameVisualWindow = 0
        local passwordVisualWindow = 0
        local shiftDown = false
        local capsLock = false
        local numLock = false

        local function clampCursor(entry)
            if entry == 'name' then
                nameCursor = math.max(nameCursor, 0)
                nameCursor = math.min(nameCursor, #name)
                if nameCursor > nameVisualWindow + #whiteSpace then
                    nameVisualWindow = nameVisualWindow +1
                elseif nameCursor < nameVisualWindow then
                    nameVisualWindow = nameVisualWindow -1
                end
                term.setCursorPos(math.max(math.min(nameCursor, #whiteSpace - 1), 0) + 2, 6)
            elseif entry == 'password' then
                passwordCursor = math.max(passwordCursor, 0)
                passwordCursor = math.min(passwordCursor, #password)
                if passwordCursor > passwordVisualWindow + #whiteSpace then
                    passwordVisualWindow = passwordVisualWindow +1
                elseif nameCursor < passwordVisualWindow then
                    passwordVisualWindow = passwordVisualWindow -1
                end
                term.setCursorPos(math.max(math.min(passwordCursor, #whiteSpace - 1), 0) + 2, 9)
            end
        end

        local function inputText(text, input)
            if input == 'name' then
                local left = string.sub(name, 1, nameCursor)
                local right = string.sub(name, nameCursor + 1, #name)
                name = left .. text .. right
                nameCursor = nameCursor + #text
                term.setCursorPos(2, 6)
                term.write(string.sub(name, nameVisualWindow, nameVisualWindow + #whiteSpace - 1))
            elseif input == 'password' then
                local left = string.sub(password, 1, passwordCursor)
                local right = string.sub(password, passwordCursor + 1, #password)
                password = left .. text .. right
                passwordCursor = passwordCursor + #text
                term.setCursorPos(2, 9)
                term.write(string.rep('*', math.min(#password, #whiteSpace - 1)))
            end
            clampCursor(input)
        end

        term.setCursorPos(math.floor(monWidth / 2) - 6, 2)
        term.setTextColor(colors.white)
        term.write('please login')
        term.setCursorBlink(true)
        term.setCursorPos(2, 5)
        if failed then
            term.setTextColor(colors.red)
        end
        term.write(nameMessage and 'email/phone number - ' .. nameMessage or 'email/phone number')
        term.setCursorPos(2, 6)
        term.setBackgroundColor(colors.gray)
        term.write(whiteSpace)
        term.setCursorPos(2, 8)
        term.setBackgroundColor(colors.black)
        term.write(passwordMessage and 'password - ' .. passwordMessage or 'password')
        term.setTextColor(colors.white)
        term.setCursorPos(2, 9)
        term.setBackgroundColor(colors.gray)
        term.write(whiteSpace)
        if message then
            term.setCursorPos((monWidth / 2) - (#message / 2), ((monHeight - 9) / 2) + 9)
            term.write(message)
        end
        term.setCursorPos(monWidth - 7, monHeight - 1)
        term.write(' login ')

        local selected = 'name'
        term.setCursorPos(2, 6)

        gui:draw()

        repeat
            local eventData = {gui:handleEvents(os.pullEvent())}
            local event = eventData[1]
            if name ~= '' and password ~= '' and not gui.buttonList.login then
                button('login', monWidth - 7, monHeight - 1, 7, 1)
                gui:draw()
            end
            if event == 'mouse_click' and eventData[2] == 1 and eventData[3] >= 2 and eventData[3] <= monWidth - 1 then
                if eventData[4] == 6 then
                    term.setCursorPos(math.min(nameCursor, #whiteSpace) + 2, 6)
                    selected = 'name'
                elseif eventData[4] == 9 then
                    term.setCursorPos(math.min(passwordCursor, #whiteSpace) + 2, 9)
                    selected = 'cursor'
                end
            elseif event == 'key' then
                local key = keys.getName(eventData[2])
                if key == 'left' then
                    nameCursor = nameCursor -1
                    clampCursor('name')
                    term.setCursorPos(math.min(nameCursor, #whiteSpace) + 2, 6)
                elseif key == 'right' then
                    nameCursor = nameCursor +1
                    clampCursor('name')
                    term.setCursorPos(math.min(nameCursor, #whiteSpace) + 2, 6)
                elseif key == 'enter' then
                    if selected == 'password' then
                        ready = true
                    end
                    selected = 'password'
                    term.setCursorPos(math.min(passwordCursor, #whiteSpace) + 2, 9)
                elseif key == 'backspace' then
                    if selected == 'name' then
                        local left = string.sub(name, 1, nameCursor - 1)
                        local right = string.sub(name, nameCursor + 1, #name)
                        name = left .. right
                        nameCursor = nameCursor -1
                        term.setCursorPos(2, 6)
                        term.write(string.sub(name, nameVisualWindow, nameVisualWindow + #whiteSpace - 1))
                        if #name < #whiteSpace then
                            term.write(' ')
                        end
                    elseif selected == 'password' then
                        local left = string.sub(password, 1, passwordCursor - 1)
                        local right = string.sub(password, passwordCursor + 1, #password)
                        password = left .. right
                        passwordCursor = passwordCursor -1
                        term.setCursorPos(2, 9)
                        term.write(string.rep('*', math.min(#password, #whiteSpace - 1)))
                        if #password < #whiteSpace then
                            term.write(' ')
                        end
                    end
                    clampCursor(selected)
                end
            elseif event == 'char' then
                inputText(eventData[2], selected)
            elseif event == 'button_click' then
                gui:flash(eventData[2])
                if eventData[2] == 'login' then
                    ready = true
                end
            elseif event == 'paste' then
                inputText(eventData[2], selected)
            end
        until ready
        ready = false
        term.setBackgroundColor(colors.black)
        term.setCursorBlink(false)
        term.clear()
        gui:remove('login')
        local reqData = JSON:encode({
            login = name,
            password = password,
            undelete = false
        })
        local reqHeaders = {
            ['Content-Type'] = 'application/json'
        }
        local request = http.post(client.createApiUrl('/auth/login', 9), reqData, reqHeaders)

        if not request then
            attemptLogin(true, 'an unkown error accured', 'might be wrong', 'might be wrong')
            return
        end

        local res = JSON:decode(request.readAll())
        if request.getResponseCode() == 400 then
            attemptLogin(true, nil, res.errors.login[0].message, res.errors.password[0].message)
        else
            token = res.token
        end

        local loginFile = fs.open('/credentials.txt', 'w')
        loginFile.write(token)
        loginFile.close()
    end
    attemptLogin()
else
    local loginFile = fs.open('/credentials.txt', 'r')
    token = loginFile.readAll()
    loginFile.close()
end

function guiInteractions()
    while true do
        local eventData = {gui:handleEvents(os.pullEvent())}
        local event = eventData[1]
        if event ~= nil then
            messageRendering(event, eventData)
        end
    end
end
local function doClient() 
    local intents = client.createIntents({
        'GUILD_MESSAGES', 
        'DIRECT_MESSAGES', 
        'MESSAGE_CONTENT'
    })
    client.connectDiscord(token, 8189, function(e, data)
        client.token = token
        if e == 'READY' then
            messageRendering(e, {
                gui = gui,
                buttonCreator = button,
                client = client,
                discordData = data
            })
        else
            messageRendering(e, data)
        end
    end)
end

parallel.waitForAll(guiInteractions, doClient)
