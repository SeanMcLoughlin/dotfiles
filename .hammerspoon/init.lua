hs.allowAppleScript(true)
local spoonsFile = hs.configdir .. "/spoons.txt"

local function readSpoonList(path)
    local spoons = {}
    local f = io.open(path, "r")
    if not f then return spoons end

    for line in f:lines() do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" and not name:match("^#") then
            table.insert(spoons, name)
        end
    end

    f:close()
    return spoons
end

pcall(hs.loadSpoon, "SpoonInstall")

if spoon.SpoonInstall then
    local Install = spoon.SpoonInstall
    Install:updateAllRepos()

    for _, spoonName in ipairs(readSpoonList(spoonsFile)) do
        if spoonName ~= "SpoonInstall" then
            Install:andUse(spoonName)
        end
    end
end

aerospaceIndicator = require("aerospace")
