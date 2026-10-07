local aerospace = "/opt/homebrew/bin/aerospace"
local item = hs.menubar.new(true, "aerospace-workspaces")

local function lines(args)
    local out = hs.execute(aerospace .. " " .. args)
    local result = {}
    for line in (out or ""):gmatch("[^\r\n]+") do
        table.insert(result, line)
    end
    return result
end

local function refresh()
    local focused = lines("list-workspaces --focused")[1]
    if not focused then
        item:setTitle("?")
        return
    end

    local parts = {}
    local seen = {}
    local function add(name)
        if seen[name] then return end
        seen[name] = true
        table.insert(parts, name)
    end

    local occupied = lines("list-workspaces --all --empty no")
    table.insert(occupied, focused)
    table.sort(occupied)
    for _, name in ipairs(occupied) do
        add(name)
    end

    for i, name in ipairs(parts) do
        if name == focused then
            parts[i] = "[" .. name .. "]"
        end
    end
    local layout = lines("list-windows --focused --format %{window-layout}")[1] or ""
    local arrow = ""
    if layout == "h_tiles" or layout == "v_tiles" then
        local right = layout == "h_tiles"
        arrow = right and "  →" or "  ↓"
    elseif layout == "floating" then
        arrow = "  ~"
    end
    item:setTitle(table.concat(parts, " ") .. arrow)
end

hs.urlevent.bind("aerospace-workspace", refresh)
refresh()

local lastScreen = hs.mouse.getCurrentScreen()
local function followMouse()
    local screen = hs.mouse.getCurrentScreen()
    if not screen or (lastScreen and screen:id() == lastScreen:id()) then return end
    lastScreen = screen
    hs.task.new(aerospace, refresh, { "focus-monitor", screen:name() }):start()
end

return {
    refresh = refresh,
    timer = hs.timer.doEvery(3, refresh),
    mouseTimer = hs.timer.doEvery(0.1, followMouse),
}
