--[[
JARVIS para ComputerCraft / CC:Tweaked com ativação por palavras-chave "JARVIS" ou "J.A.R.V.I.S" no chat.
Salve como /startup.lua e use com Plethora ChatBox ou periférico que emita eventos 'chat'.
]]

-- ===================== CONFIG ===================== --
local J = {}
J.version = "1.2.0"
J.color = colors.cyan
J.accent = colors.orange
J.bg = colors.black
J.fg = colors.white
J.monitor = nil
J.monitorSide = nil
J.useMonitor = false
J.tracking = false
J.trackPoints = {}
J.rednetOpen = false
J.channel = nil
J.isTurtle = turtle ~= nil
J.logFile = "/jarvis.log"
J.awake = false
J.wakeTimeout = 20
J.lastWake = 0
J.keywords = {"jarvis", "j.a.r.v.i.s"}

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
  local old = term.getTextColor()
  if col then term.setTextColor(col) end
  print(text)
  if col then term.setTextColor(old) end
  if J.useMonitor and J.monitor then
    local mw, mh = J.monitor.getSize()
    local x, y = J.monitor.getCursorPos()
    if y > mh then J.monitor.scroll(1) y = mh end
    if col then J.monitor.setTextColor(col) end
    J.monitor.write(text)
    J.monitor.setCursorPos(1, y+1)
    if col then J.monitor.setTextColor(colors.white) end
  end
end

local function banner()
  term.setBackgroundColor(J.bg)
  term.setTextColor(J.fg)
  term.clear()
  term.setCursorPos(1,1)
  local w,h = term.getSize()
  paintutils.drawFilledBox(1,1,w,3, colors.gray)
  term.setCursorPos(2,2)
  term.setTextColor(J.color)
  term.write("JARVIS ")
  term.setTextColor(colors.white)
  term.write("v"..J.version)
  term.setCursorPos(w-7,2)
  term.setTextColor(J.accent)
  term.write(timeStr())
  term.setTextColor(J.fg)
  term.setCursorPos(1,5)
end

-- ===================== COMANDOS ===================== --
local commands = {}
local function register(name, desc, fn) commands[name] = {desc=desc, run=fn} end
register("help", "Lista comandos.", function() for k,v in pairs(commands) do mprint(k.." - "..v.desc) end end)
register("hora", "Mostra a hora.", function() mprint("Hora: "..timeStr(), J.accent) end)

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

local function checkKeyword(msg)
  local lowerMsg = msg:lower()
  for _,kw in ipairs(J.keywords) do
    if lowerMsg:find(kw) then return true end
  end
  return false
end

-- ===================== LOOP ===================== --
local function prompt()
  term.setTextColor(J.color)
  io.write("JARVIS> ")
  term.setTextColor(J.fg)
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
    if checkKeyword(message) then wakeJarvis() end
  end
end

local function main()
  banner()
  mprint("Modo de espera. Diga 'JARVIS' ou 'J.A.R.V.I.S' no chat para ativar.")
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
