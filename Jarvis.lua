--[[
JARVIS para ComputerCraft / CC:Tweaked com ativação por palavra-chave no chat.
Salve como /startup.lua e use com Plethora ChatBox ou periférico que emita eventos 'chat'.
Adaptado para monitor 2x4, monitorando chat continuamente e respondendo apenas com palavra-chave.
]]

-- ===================== CONFIG ===================== --
local J = {}
J.version = "1.1.0"
J.color = colors.cyan
J.accent = colors.orange
J.bg = colors.black
J.fg = colors.white
J.monitor = peripheral.wrap("monitor_0") -- Conecta ao monitor_0
J.monitorSide = "monitor_0"
J.useMonitor = true -- Habilita o uso do monitor
J.tracking = false
J.trackPoints = {}
J.rednetOpen = false
J.channel = nil
J.isTurtle = turtle ~= nil
J.logFile = "/jarvis.log"
J.keyword = "jarvis"
J.awake = false
J.wakeTimeout = 20
J.lastWake = 0
J.gptApiKey = "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" -- Insira sua chave de API da OpenAI
J.gptApiUrl = "https://api.openai.com/v1/chat/completions" -- URL da API do ChatGPT

-- ===================== UTIL ===================== --
local function log(line)
  local h = fs.open(J.logFile, fs.exists(J.logFile) and "a" or "w")
  h.writeLine(os.date("%d/%m/%Y %H:%M:%S") .. " | " .. line)
  h.close()
end

local function timeStr() return textutils.formatTime(os.time(), true) end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function splitWords(s) local t={} for w in s:gmatch("[^%s]+") do t[#t+1]=w end return t end

local function mprint(text, col)
  if J.useMonitor and J.monitor then
    local mw, mh = J.monitor.getSize() -- 4x2
    local x, y = J.monitor.getCursorPos()
    -- Truncar texto para caber na largura do monitor (4 caracteres)
    text = text:sub(1, mw)
    if y > mh then
      J.monitor.scroll(1)
      y = mh
    end
    if col then J.monitor.setTextColor(col) end
    J.monitor.clearLine()
    J.monitor.setCursorPos(1, y)
    J.monitor.write(text)
    J.monitor.setCursorPos(1, y + 1)
    if col then J.monitor.setTextColor(colors.white) end
  else
    local old = term.getTextColor()
    if col then term.setTextColor(col) end
    print(text)
    if col then term.setTextColor(old) end
  end
end

local function banner()
  if J.useMonitor and J.monitor then
    J.monitor.setBackgroundColor(J.bg)
    J.monitor.setTextColor(J.fg)
    J.monitor.clear()
    J.monitor.setCursorPos(1, 1)
    J.monitor.setTextColor(J.color)
    J.monitor.write("JARV") -- Ajustado para caber em 4 caracteres
    J.monitor.setTextColor(J.fg)
    J.monitor.setCursorPos(1, 2)
  else
    term.setBackgroundColor(J.bg)
    term.setTextColor(J.fg)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(J.color)
    term.write("JARV")
    term.setTextColor(J.fg)
    term.setCursorPos(1, 2)
  end
end

-- ===================== GPT INTEGRATION ===================== --
local function callGpt(prompt)
  if not http then
    mprint("HTTP?", colors.red)
    log("FATAL: HTTP API não habilitado")
    return nil
  end

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. J.gptApiKey
  }
  local body = textutils.serializeJSON({
    model = "gpt-3.5-turbo",
    messages = {{ role = "user", content = prompt }},
    max_tokens = 20 -- Reduzido para respostas curtas no monitor 2x4
  })

  local response, err = http.post(J.gptApiUrl, body, headers)
  if not response then
    mprint("API?", colors.red)
    log("FATAL: Erro ao chamar GPT API: " .. (err or "Desconhecido"))
    return nil
  end

  local responseBody = response.readAll()
  response.close()
  local data = textutils.unserializeJSON(responseBody)
  if data and data.choices and data.choices[1] and data.choices[1].message then
    return trim(data.choices[1].message.content)
  else
    mprint("RES?", colors.red)
    log("FATAL: Resposta inválida da API")
    return nil
  end
end

-- ===================== COMANDOS ===================== --
local commands = {}
local function register(name, desc, fn) commands[name] = {desc=desc, run=fn} end
register("help", "Lista comandos.", function() for k,v in pairs(commands) do mprint(k, J.color) end end)
register("hora", "Mostra a hora.", function() mprint(timeStr():sub(1, 4), J.accent) end)
register("gpt", "Consulta GPT. Uso: gpt <pergunta>", function(args)
  local prompt = table.concat(args, " ")
  if prompt == "" then
    mprint("ASK?", colors.red)
    return
  end
  mprint("GPT>", J.color)
  local response = callGpt(prompt)
  if response then
    mprint(response:sub(1, 4), colors.green)
  end
end)

-- ===================== AWAKE SYSTEM ===================== --
local function wakeJarvis()
  J.awake = true
  J.lastWake = os.clock()
  mprint("ON!", colors.lime)
end

local function sleepJarvis()
  J.awake = false
  mprint("OFF!", colors.gray)
end

-- ===================== LOOP ===================== --
local function prompt()
  if J.useMonitor and J.monitor then
    J.monitor.setTextColor(J.color)
    J.monitor.write("J>")
    J.monitor.setTextColor(J.fg)
  else
    term.setTextColor(J.color)
    io.write("J>")
    term.setTextColor(J.fg)
  end
  return read()
end

local function runCommand(line)
  local s = trim(line or "")
  if s == "" then return end
  log("CMD: "..s)
  local args = splitWords(s)
  local cmd = table.remove(args, 1)
  local c = commands[cmd]
  if c then pcall(function() c.run(args) end) else mprint("CMD?", colors.red) end
end

local function chatListener()
  while true do
    local event, username, message = os.pullEvent("chat")
    if message:lower():find(J.keyword:lower()) then
      wakeJarvis()
      local args = splitWords(trim(message:lower():gsub(J.keyword:lower(), "")))
      if #args > 0 then
        runCommand(table.concat(args, " "))
      end
    end
  end
end

local function main()
  if J.useMonitor and not J.monitor then
    mprint("MON?", colors.red)
    log("FATAL: Monitor_0 não encontrado")
    return
  end
  if not J.gptApiKey or J.gptApiKey == "SUA_CHAVE_API_AQUI" then
    mprint("API?", colors.yellow)
    log("AVISO: Chave da API do GPT não configurada")
  end
  banner()
  mprint("OK", colors.green)
  parallel.waitForAny(
    function()
      while true do
        if J.awake then
          local line = prompt()
          runCommand(line)
        else
          os.sleep(0.1)
        end
      end
    end,
    function()
      while true do
        os.sleep(0.2)
        if J.awake and (os.clock() - J.lastWake > J.wakeTimeout) then
          sleepJarvis()
        end
      end
    end,
    chatListener
  )
end

local ok, err = pcall(main)
if not ok then mprint("ERR!", colors.red) log("FATAL: "..tostring(err)) end
