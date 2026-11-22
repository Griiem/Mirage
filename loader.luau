local HttpService = game:GetService("HttpService")

local _version = "1.6.66"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. _version .. "/main.lua"))()

local OWNER = "Griiem"
local REPO = "Mirage"
local BRANCH = "main"

local RAW_URL = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(OWNER, REPO, BRANCH)
local API_URL = ("https://api.github.com/repos/%s/%s/contents/tabs"):format(OWNER, REPO)
local CORE_PATH = "core/SkinEngine.luau"

local Window = WindUI:CreateWindow({
    Title = "",
    Icon = "chess-queen",
    Author = nil,
    Folder = "Mirage",
    ToggleKey = Enum.KeyCode.L,
    Size = UDim2.fromScale(.26, .19),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(900, 900),
    Transparent = true,
    Theme = "Midnight",
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    BackgroundImageTransparency = 1,
    Background = "8508980536",
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Button",
                Content = "No function yet",
                Icon = "user",
                Duration = 3,
            })
        end,
    },
})

Window:Tag({
    Title = "v0.0.1",
    Icon = "rocket",
    Color = Color3.fromHex("#89fa98"),
    Radius = 6.333,
})

local coreOk, Skins = pcall(function()
    local source = game:HttpGet(RAW_URL .. CORE_PATH)
    assert(source and #source > 0, "Empty source")

    local chunk, compileError = loadstring(source)
    assert(chunk, compileError or "Compilation failed")

    return chunk()(RAW_URL)
end)

if not coreOk or type(Skins) ~= "table" then
    local reason = tostring(Skins)

    warn("[Mirage] Failed to load " .. CORE_PATH .. " from " .. RAW_URL .. CORE_PATH .. ": " .. reason)

    WindUI:Notify({
        Title = "Mirage",
        Content = "Could not load " .. CORE_PATH .. ": " .. reason:sub(1, 120),
        Icon = "x",
        Duration = 8,
    })
    return
end

local Mirage = {
    RAW_URL = RAW_URL,
    Skins = Skins,
}

local function loadTab(name)
    local url = RAW_URL .. "tabs/" .. name .. ".luau"

    local success, err = pcall(function()
        local source = game:HttpGet(url)
        assert(source and #source > 0, "Empty source")

        local chunk, compileError = loadstring(source)
        assert(chunk, compileError or "Compilation failed")

        local setup = chunk()

        assert(
            type(setup) == "function",
            "Tab must return a function"
        )

        setup(Window, WindUI, Mirage)
    end)

    if not success then
        warn("[Mirage] Failed to load tab '" .. name .. "': " .. tostring(err))
        return false
    end

    return true
end

local listed, files = pcall(function()
    return HttpService:JSONDecode(game:HttpGet(API_URL .. "?ref=" .. BRANCH))
end)

if not listed or type(files) ~= "table" then
    warn("[Mirage] Failed to list tabs: " .. tostring(files))

    WindUI:Notify({
        Title = "Mirage",
        Content = "Could not list the tabs folder.",
        Icon = "x",
        Duration = 5,
    })
    return
end

table.sort(files, function(a, b)
    return a.name < b.name
end)

for _, file in ipairs(files) do
    if file.type == "file" then
        local tabName = file.name:match("^(.+)%.luau$")

        if tabName then
            loadTab(tabName)
        end
    end
end

Window:OnDestroy(function()
    Skins:Cleanup()
end)

task.spawn(function()
    if not Skins.HasFs then
        WindUI:Notify({
            Title = "Mirage",
            Content = "Your executor does not support writefile/getcustomasset.",
            Icon = "x",
            Duration = 6,
        })
        return
    end

    local ok, loaded = pcall(function()
        return Skins:Start()
    end)

    if not ok or not loaded then
        WindUI:Notify({
            Title = "Mirage",
            Content = "Could not read skins/index.json.",
            Icon = "x",
            Duration = 5,
        })
    end
end)

print("[Mirage] Loaded...")
