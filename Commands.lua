local _, CL = ...

local HELP = {
    "/cll               open or close the options window",
    "/loot              who won what, by instance and boss",
    "/cll session       master looter: your tradable items and the loot session",
    "/cll sim [n]       simulate n loot rolls (1-8) to try the frames",
    "/cll next|previous|inspect|need|greed|pass  controller mode: for keys and macros",
    "/cll debug [on|off]  trace every roll in chat, to report a bug",
}

SLASH_CLEANLOOT1 = "/cleanloot"
SLASH_CLEANLOOT2 = "/cll"
SlashCmdList["CLEANLOOT"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd, rest = cmd:lower(), rest:lower()

    if cmd == "" then
        CL.Options.Toggle()
    elseif cmd == "options" or cmd == "config" then
        CL.Options.Open()
    elseif cmd == "controller" then
        CL.Options.OpenController()
    elseif cmd == "auto" then
        -- the argument keeps its case: an item link must not be lowercased
        CL.AutoRoll.Command((msg or ""):match("^%s*%S+%s*(.-)%s*$"))
    elseif cmd == "watch" then
        CL.Watchlist.Command((msg or ""):match("^%s*%S+%s*(.-)%s*$"))
    elseif cmd == "sim" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        if sub == "clear" then
            CL.Sim.Clear()
            CL.Print("simulated rolls cleared.")
        elseif sub == "colors" or sub == "colours" then
            CL.Sim.Colors()
        elseif sub == "master" then
            CL.MasterLoot.Simulate()
        elseif sub == "group" then
            local n = CL.Sim.SetGroupSize(tonumber(arg) or 4)
            CL.Print(("sim group: %d other players (applies to the next drops)."):format(n))
        else
            CL.Sim.Start(tonumber(sub) or 1)
        end
    elseif cmd == "master" then
        if rest == "on" or rest == "off" then
            CL.MasterLoot.SetEnabled(rest == "on")
        end
        CL.Print("master loot features: " .. (CL.MasterLoot.Enabled() and "on" or "off") .. " (/cll master on|off).")
    elseif cmd == "session" then
        CL.Session.Command(rest)
    elseif cmd == "take" then
        CL.TakeAll.Run(false)
    elseif cmd == "history" or cmd == "log" then
        CL.LootWindow.Command()
    elseif cmd == "learned" then
        CL.LootLearn.Command((msg or ""):match("^%s*%S+%s*(.-)%s*$"))
    elseif cmd == "trade" then
        CL.TradeFill.Command()
    elseif cmd == "de" then
        CL.Disenchant.Command((msg or ""):match("^%s*%S+%s*(.-)%s*$"))
    elseif cmd == "gargul" then
        CL.MasterLoot.AskGargul(true)
    elseif cmd == "debug" then
        if rest == "on" then CL.db.debug = true
        elseif rest == "off" then CL.db.debug = false
        else CL.db.debug = not CL.db.debug end
        CL.Print("debug " .. (CL.db.debug and "on: every roll is traced in chat (and kept in the saved variables)." or "off."))
    elseif cmd == "restore" then
        local n = CL.RestoreRolls()
        CL.Print(n > 0 and ("%d running roll(s) brought back."):format(n) or "no running roll to bring back.")
    elseif cmd == "next" or cmd == "previous" or cmd == "inspect"
        or cmd == "need" or cmd == "greed" or cmd == "pass" then
        CL.Keyboard.Action(cmd)
    else
        CL.Print("v" .. CL.Version() .. " -- commands:")
        for _, line in ipairs(HELP) do print("  " .. line) end
    end
end
