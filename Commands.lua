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
    elseif cmd == "sim" then
        CL.Sim.Start(tonumber(rest) or 1)
    elseif cmd == "session" then
        CL.Session.Toggle()
    elseif cmd == "debug" then
        if rest == "on" then CL.db.debug = true
        elseif rest == "off" then CL.db.debug = false
        else CL.db.debug = not CL.db.debug end
        CL.Print("debug " .. (CL.db.debug and "on: every roll is traced in chat (and kept in the saved variables)." or "off."))
    elseif cmd == "next" or cmd == "previous" or cmd == "inspect"
        or cmd == "need" or cmd == "greed" or cmd == "pass" then
        CL.Keyboard.Action(cmd)
    else
        CL.Print("v" .. CL.Version() .. " -- commands:")
        for _, line in ipairs(HELP) do print("  " .. line) end
    end
end
