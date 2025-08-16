--[[
JARVIS para ComputerCraft / CC:Tweaked com ativação por palavra-chave no chat.
Salve como /startup.lua e use com Plethora ChatBox ("Chat Box").
Responde no chat do Minecraft usando GPT para processar intenções; monitor 2x4 exibe "J.A.R.V.I.S" e status.
]]

-- ===================== CONFIG ===================== --
local J = {}
J.version = "1.1.2" -- Atualizado para indicar ajuste de periférico
J.color = colors.cyan
J.accent = colors.orange
J.bg = colors.black
J.fg = colors.white
J.monitor = peripheral.wrap("monitor_0") -- Conecta ao monitor_0 (2x4)
J.monitorSide = "monitor_0"
J.useMonitor = true
J.chatBox = peripheral.wrap("Chat Box") -- Conecta ao Chat Box do Advanced Peripherals
J.chatBoxSide = "Chat Box"
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
J.gptApiUrl = "https://api.openai.com/v1/chat/completions"

-- ===================== UTIL ===================== --
local function log(line)
  local h = fs.open(J.logFile, fs.exists(J.logFile) and "a" or "w")
  if h then
    h.writeLine(os.date("%d/%m/%Y %H:%M:%S") .. " | " .. line)
    h.close()
  end
end

local function timeStr() return textutils.formatTime(os.time(), true) end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function splitWords(s) local t={} for w in s:gmatch("[^%s]+") do t[#t+1]=w end return t end

local function mprint(text, col) -- Apenas para status no monitor
  if J.useMonitor and J.monitor then
    local mw, mh = J.monitor.getSize() -- 4x2
    local x, y = J.monitor.getCursorPos()
    text = text:sub(1, mw) -- Truncar para 4 caracteres
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
  end
end

local function sendToChat(message)
  if J.chatBox then
    local success, err = pcall(function() J.chatBox.say(message) end)
    if not success then
      mprint("CHAT?", colors.red)
      log("FATAL: Erro ao enviar mensagem ao chat: " .. tostring(err))
    end
  else
    mprint("CHAT?", colors.red)
    log("FATAL: Chat Box não encontrado")
  end
end

local function banner()
  if J.useMonitor and J.monitor then
    J.monitor.setBackgroundColor(J.bg)
    J.monitor.setTextColor(J.fg)
    J.monitor.clear()
    J.monitor.setCursorPos(1, 1)
    J.monitor.setTextColor(J.color)
    J.monitor.write("J.A.") -- Linha 1: J.A.
    J.monitor.setCursorPos(1, 2)
    J.monitor.write("R.V.") -- Linha 2: R.V. (J.A.R.V.I.S em 2x4)
    J.monitor.setTextColor(J.fg)
  end
end

-- ===================== GPT INTEGRATION ===================== --
local function callGpt(prompt)
  if not http then
    mprint("HTTP?", colors.red)
    log("FATAL: HTTP API não habilitado")
    sendToChat("Erro: HTTP API não habilitado.")
    return nil
  end

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. J.gptApiKey
  }
  local body = textutils.serializeJSON({
    model = "gpt-3.5-turbo",
    messages = {
      {
        role = "system",
        content = "Você é JARVIS, um assistente inteligente. Comandos disponíveis: help (lista comandos), hora (mostra a hora). Se a mensagem do usuário for exatamente um comando, responda com JSON: {type: 'command', name: 'comando'}. Caso contrário, responda com JSON: {type: 'response', text: 'sua resposta amigável e útil'}. Sempre use JSON."
      },
      { role = "user", content = prompt }
    },
    max_tokens = 100
  })

  local response, err = http.post(J.gptApiUrl, body, headers)
  if not response then
    mprint("API?", colors.red)
    log("FATAL: Erro ao chamar GPT API: " .. (err or "Desconhecido"))
    sendToChat("Erro ao conectar com o assistente.")
    return nil
  end

  local responseBody = response.readAll()
  response.close()
  local data = textutils.unserializeJSON(responseBody)
  if data and data.choices and data.choices[1] and data.choices[1].message then
    local gptResponse = trim(data.choices[1].message.content)
    local jsonData = textutils.unserializeJSON(gptResponse)
    if jsonData and jsonData.type then
      return jsonData
    else
      return {type = "response", text = gptResponse}
    end
  else
    mprint("RES?", colors.red)
    log("FATAL: Resposta inválida da API")
    sendToChat("Erro: Resposta inválida do assistente.")
    return nil
  end
end

-- ===================== COMANDOS ===================== --
local commands = {}
local function register(name, desc, fn) commands[name] = {desc=desc, run=fn} end
register("help", "Lista comandos.", function() sendToChat("Comandos: help, hora") end)
register("hora", "Mostra a hora.", function() sendToChat("Hora: " .. timeStr()) end)

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
local function runCommand(line)
  local s = trim(line or "")
  if s == "" then
    sendToChat("Oi! Como posso ajudar?")
    return
  end
  log("CMD: " .. s)
  
  local gptResult = callGpt(s)
  if gptResult then
    if gptResult.type == "command" and gptResult.name then
      local cmd = commands[gptResult.name]
      if cmd then
        pcall(cmd.run)
      else
        sendToChat("Comando desconhecido: " .. gptResult.name)
      end
    elseif gptResult.type == "response" and gptResult.text then
      sendToChat(gptResult.text)
    else
      sendToChat("Resposta inválida do assistente.")
    end
  else
    sendToChat("Erro ao processar a mensagem.")
  end
end

local function chatListener()
  while true do
    local event, username, message = os.pullEvent("chat")
    if message:lower():find(J.keyword:lower()) then
      wakeJarvis()
      local remaining = trim(message:lower():gsub(J.keyword:lower(), ""))
      runCommand(remaining)
    end
  end
end

local function main()
  if J.useMonitor and not J.monitor then
    log("FATAL: Monitor_0 não encontrado")
    sendToChat("Erro: Monitor_0 não encontrado.")
    return
  end
  if not J.chatBox then
    log("FATAL: Chat Box não encontrado")
    mprint("CHAT?", colors.red)
    return
  end
  if not J.gptApiKey or J.gptApiKey == "SUA_CHAVE_API_AQUI" then
    mprint("API?", colors.yellow)
    log("AVISO: Chave da API do GPT não configurada")
    sendToChat("Aviso: Configure a chave da API do GPT.")
  end
  banner()
  mprint("OK", colors.green)
  parallel.waitForAny(
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
if not ok then
  mprint("ERR!", colors.red)
  log("FATAL: " .. tostring(err))
  sendToChat("Erro fatal: " .. tostring(err))
end
