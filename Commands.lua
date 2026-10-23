local ADDON_NAME, CL = ...

local HELP = {
    "/cll sim [n]       simulate n loot rolls (1-8) from a loot table, fake group",
    "/cll sim colors    one drop of every colour, common to legendary",
    "/cll sim group <n> other players in the simulated group (1-39, default 4)",
    "/cll sim chat      toggle the simulator's chat lines (off: the game prints its own)",
    "/cll sim clear     remove all simulated rolls",
    "/cll options       open the options panel",
    "/cll restore       bring back rolls still running (done automatically at login/reload)",
    "/cll debug [on|off]  trace every roll in chat (why one did or did not show)",
    "/cll native show|hide  Blizzard's own roll frames (hidden by default)",
    "/cll grow up|down  stacking direction",
    "/cll scale <0.8-1.5>  frame scale",
}

SLASH_CLEANLOOT1 = "/cleanloot"
SLASH_CLEANLOOT2 = "/cll"
SlashCmdList["CLEANLOOT"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd, rest = cmd:lower(), rest:lower()

    if cmd == "sim" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        if sub == "clear" then
            CL.Sim.Clear()
            CL.Print("simulated rolls cleared.")
        elseif sub == "colors" or sub == "colours" then
            CL.Sim.Colors()
        elseif sub == "chat" then
            CL.Sim.chat = not CL.Sim.chat
            CL.Print("sim chat output: " .. (CL.Sim.chat and "on" or "off") .. ".")
        elseif sub == "group" then
            local n = CL.Sim.SetGroupSize(tonumber(arg) or 4)
            CL.Print(("sim group: %d other players (applies to the next drops)."):format(n))
        else
            CL.Sim.Start(tonumber(sub) or 1)
        end
    elseif cmd == "debug" then
        if rest == "on" then CL.db.debug = true
        elseif rest == "off" then CL.db.debug = false
        else CL.db.debug = not CL.db.debug end
        CL.Print("debug " .. (CL.db.debug and "on: every roll is traced in chat (and kept in the saved variables)." or "off."))
    elseif cmd == "restore" then
        local n = CL.RestoreRolls()
        CL.Print(n > 0 and ("%d running roll(s) brought back."):format(n) or "no running roll to bring back.")
    elseif cmd == "options" or cmd == "config" or cmd == "menu" then
        CL.Options.Open()
    elseif cmd == "native" and (rest == "show" or rest == "hide") then
        CL.Native.SetHidden(rest == "hide")
        CL.Print(rest == "hide" and "Blizzard's roll frames hidden." or "Blizzard's roll frames shown again.")
    elseif cmd == "grow" and (rest == "up" or rest == "down") then
        CL.db.growDirection = rest:upper()
        CL.RollFrames.Layout()
        CL.Print("stacking " .. rest .. ".")
    elseif cmd == "scale" and tonumber(rest) then
        local scale = math.max(0.8, math.min(1.5, tonumber(rest)))
        CL.db.frameScale = scale
        CL.RollFrames.Layout()
        CL.Print(("scale %.2f."):format(scale))
    else
        CL.Print("v" .. CL.Version() .. " -- commands:")
        for _, line in ipairs(HELP) do print("  " .. line) end
    end
end
