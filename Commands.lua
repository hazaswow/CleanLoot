local _, CL = ...

local HELP = {
    "/cll               open or close the options window",
    "/cll controller    open the controller mode page of the options window",
    "/cll auto          open the auto-roll page of the options window",
    "/cll auto need|greed|pass [item]  always roll that way on an item (shift-click it)",
    "/cll auto remove [item] | list    forget an item's rule | list the rules",
    "/cll watch         open the watchlist page of the options window",
    "/cll watch [item] [note]  highlight an item when it drops, with an optional note",
    "/cll watch note [item] <text> | remove [item] | list",
    "/cll skin [clean|blizzard]  the look of the roll frames: CleanLoot's own, or the game's classic one",
    "/cll sim [n]       simulate n loot rolls (1-8) with a fake group",
    "/cll sim colors    one simulated drop of every colour",
    "/cll sim master    a simulated master-loot roll result window",
    "/cll master [on|off]  turn CleanLoot's master loot features on or off",
    "/cll session       the items of your bags you can hand out (master looter)",
    "/cll session start | test | stop   start a timed loot session | try one alone | cancel it",
    "/cll take          give yourself every master-loot item of the open loot window",
    "/cll history       the record of who won what, by instance and boss (also /loot)",
    "/cll learned [boss | clear]  what the bosses you killed dropped, as CleanLoot saw it",
    "/cll trade         put in the open trade window the items its player won",
    "/cll de [ask | stop | clear | <name>]  the disenchanter: ask the group who can, or designate one",
    "/cll gargul        choose who announces the hand-outs when Gargul is installed",
    "/cll sim group <n> other players in the simulated group (1-39, default 4)",
    "/cll sim clear     remove the simulated rolls",
    "/cll restore       bring back rolls still running (automatic at login and /reload)",
    "/cll next|previous select a visible loot roll",
    "/cll inspect       toggle the selected item's inspection",
    "/cll need|greed|pass  roll on the selected item",
    "/cll debug [on|off]  trace every roll in chat (why one did or did not show)",
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
    elseif cmd == "skin" then
        if rest == "clean" or rest == "blizzard" then CL.RollFrames.SetSkin(rest) end
        CL.Print(("roll frame skin: %s (/cll skin clean|blizzard)."):format(CL.RollFrames.Skin()))
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
