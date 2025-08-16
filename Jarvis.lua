--[[
JARVIS para ComputerCraft / CC:Tweaked com ativação por palavra-chave no chat.
Salve como /startup.lua e use com Plethora ChatBox ou periférico que emita eventos 'chat'.
Modificado para exibir tudo no monitor_0 e integrar com API do GPT (OpenAI).
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
J.gptApiKey = "SUA_CHAVE_API_AQUI" -- Insira sua chave de API da OpenAI
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
    local mw, mh = J.monitor.getSize()
    local x, y = J.monitor.getCursorPos()
    if y > mh then J.monitor.scroll(1) y = mh end
    if col then J.monitor.setTextColor(col) end
    J.monitor.write(text)
    J.monitor.setCursorPos(1, y+1)
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
    J.monitor.setCursorPos(1,1)
    local w, h = J.monitor.getSize()
    paintutils.drawFilledBox(1, 1, w, 3, colors.gray)
    J.monitor.setCursorPos(2, 2)
    J.monitor.setTextColor(J.color)
    J.monitor.write("JARVIS ")
    J.monitor.setTextColor(colors.white)
    J.monitor.write("v"..J.version)
    J.monitor.setCursorPos(w-7, 2)
    J.monitor.setTextColor(J.accent)
    J.monitor.write(timeStr())
    J.monitor.setTextColor(J.fg)
    J.monitor.setCursorPos(1, 5)
  else
    term.setBackgroundColor(J.bg)
    term.setTextColor(J.fg)
    term.clear()
    term.setCursorPos(1,1)
    local w, h = term.getSize()
    paintutils.drawFilledBox(1, 1, w, 3, colors.gray)
    term.setCursorPos(2, 2)
    term.setTextColor(J.color)
    term.write("JARVIS ")
    term.setTextColor(colors.white)
    term.write("v"..J.version)
    term.setCursorPos(w-7, 2)
    term.setTextColor(J.accent)
    term.write(timeStr())
    term.setTextColor(J.fg)
    term.setCursorPos(1, 5)
  end
end

-- ===================== GPT INTEGRATION ===================== --
local function callGpt(prompt)
  if not http then
    mprint("Erro: HTTP API não está habilitado.", colors.red)
    log("FATAL: HTTP API não habilitado")
    return nil
  end

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. J.gptApiKey
  }
  local body = textutils.serializeJSON({
    model = "gpt-3.5-turbo", -- ou "gpt-4" se disponível
    messages = {{ role = "user", content = prompt }},
    max_tokens = 100 -- Limite para respostas curtas
  })

  local response, err = http.post(J.gptApiUrl, body, headers)
  if not response then
    mprint("Erro ao chamar API: " .. (err or "Desconhecido"), colors.red)
    log("FATAL: Erro ao chamar GPT API: " .. (err or "Desconhecido"))
    return nil
  end

  local responseBody = response.readAll()
  response.close()
  local data = textutils.unserializeJSON(responseBody)
  if data and data.choices and data.choices[1] and data.choices[1].message then
    return trim(data.choices[1].message.content)
  else
    mprint("Erro: Resposta inválida da API.", colors.red)
    log("FATAL: Resposta inválida da API")
    return nil
  end
end

-- ===================== COMANDOS ===================== --
local commands = {}
local function register(name, desc, fn) commands[name] = {desc=desc, run=fn} end
register("help", "Lista comandos.", function() for k,v in pairs(commands) do mprint(k.." - "..v.desc) end end)
register("hora", "Mostra a hora.", function() mprint("Hora: "..timeStr(), J.accent) end)
register("gpt", "Consulta a API do GPT. Uso: gpt <pergunta>", function(args)
  local prompt = table.concat(args, " ")
  if prompt == "" then
    mprint("Erro: Forneça uma pergunta para o GPT.", colors.red)
    return
  end
  mprint("Perguntando ao GPT: " .. prompt, J.color)
  local response = callGpt(prompt)
  if response then
    mprint("Resposta: " .. response, colors.green)
  end
end)

-- ===================== AWAKE SYSTEM ===================== --
local function wakeJarvis()
  J.awake = true
  J.lastWake = os.clock()
  mprint(">> Acordei, senhor(a).", colors.lime)
end

local function sleepJarvis()
  J.awake = false
  mprint(">> Entrando em modo de espera.", colors.gray)
end

-- ===================== LOOP ===================== --
local function prompt()
  if J.useMonitor and J.monitor then
    J.monitor.setTextColor(J.color)
    J.monitor.write("JARVIS> ")
    J.monitor.setTextColor(J.fg)
  else
    term.setTextColor(J.color)
    io.write("JARVIS> ")
    term.setTextColor(J.fg)
  end
  return read()
end

local function runCommand(line)
  local s = trim(line or "")
  if s=="" then return end
  log("CMD: "..s)
  local args = splitWords(s)
  local cmd = table.remove(args,1)
  local c = commands[cmd]
  if c then pcall(function() c.run(args) end) else mprint("Comando desconhecido.") end
end

local function tick()
  if J.awake and (os.clock() - J.lastWake > J.wakeTimeout) then sleepJarvis() end
end

local function chatListener()
  while true do
    local event, username, message = os.pullEvent("chat")
    if message:lower():find(J.keyword:lower()) then wakeJarvis() end
  end
end

local function main()
  if J.useMonitor and not J.monitor then
    mprint("Erro: Monitor_0 não encontrado.", colors.red)
    log("FATAL: Monitor_0 não encontrado")
    return
  end
  if not J.gptApiKey or J.gptApiKey == "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" then
    mprint("Aviso: Configure a chave da API do GPT em J.gptApiKey.", colors.yellow)
    log("AVISO: Chave da API do GPT não configurada")
  end
  banner()
  mprint("Modo de espera. Diga a palavra-chave no chat para ativar.")
  parallel.waitForAny(function()
    while true do
      if J.awake then
        local line = prompt()
        runCommand(line)
      else os.sleep(0.1) end
    end
  end,
  function() while true do os.sleep(0.2) tick() end end,
  chatListener)
end

local ok, err = pcall(main)
if not ok then mprint("Erro: "..tostring(err), colors.red) log("FATAL: "..tostring(err)) end
