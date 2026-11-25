local _version = "1.6.66"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. _version .. "/main.lua"))()

local OWNER = "Griiem"
local REPO = "Mirage"
local BRANCH = "main"

local RAW_URL = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(OWNER, REPO, BRANCH)
local CORE_PATH = "core/SkinEngine.luau"
local TAB_NAMES = { "Catalog", "Skins" }

local SKINS_API = { "Prepare", "Start", "Refresh", "SetEnabled", "SetLocalLoadout", "Report", "Debug", "Count", "Cleanup" }
local CATALOG_API = { "Search", "Lookup", "FetchAsset", "BundleAssets", "KindOf" }

local function fetchSource(path)
    local source = game:HttpGet(RAW_URL .. path .. "?t=" .. os.time())
    assert(source and #source > 0, "Empty source for " .. path)

    local chunk, compileError = loadstring(source)
    assert(chunk, "Compile error in " .. path .. ": " .. tostring(compileError))

    return chunk
end

local function missingFunctions(module, names)
    local missing = {}

    for _, name in names do
        if type(module[name]) ~= "function" then
            table.insert(missing, name)
        end
    end

    return missing
end

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

local function report(message)
    warn("[Mirage] " .. message)

    WindUI:Notify({
        Title = "Mirage",
        Content = message:sub(1, 160),
        Icon = "x",
        Duration = 10,
    })
end

local coreOk, Skins = pcall(function()
    return fetchSource(CORE_PATH)()(RAW_URL)
end)

if not coreOk or type(Skins) ~= "table" then
    report("Could not load " .. CORE_PATH .. ": " .. tostring(Skins))
    return
end

local missingSkins = missingFunctions(Skins, SKINS_API)

if #missingSkins > 0 then
    report(CORE_PATH .. " is outdated or incomplete. Missing: " .. table.concat(missingSkins, ", ") .. ". Replace it on GitHub.")
    return
end

Skins:Prepare()

local Mirage = {
    RAW_URL = RAW_URL,
    Skins = Skins,
}

function Mirage.Require(path)
    return fetchSource(path)()
end

local catalogOk, Catalog = pcall(function()
    return Mirage.Require("core/Catalog.luau")()
end)

if catalogOk and type(Catalog) == "table" then
    local missingCatalog = missingFunctions(Catalog, CATALOG_API)

    if #missingCatalog > 0 then
        report("core/Catalog.luau is outdated or incomplete. Missing: " .. table.concat(missingCatalog, ", ") .. ". Replace it on GitHub.")
    else
        Mirage.Catalog = Catalog
        Skins.Catalog = Catalog
    end
else
    report("Could not load core/Catalog.luau: " .. tostring(Catalog))
end

local function loadTab(name)
    local success, err = pcall(function()
        local setup = Mirage.Require("tabs/" .. name .. ".luau")

        assert(
            type(setup) == "function",
            "Tab must return a function"
        )

        setup(Window, WindUI, Mirage)
    end)

    if not success then
        report("Tab '" .. name .. "' failed: " .. tostring(err))
        return false
    end

    return true
end

for _, tabName in TAB_NAMES do
    loadTab(tabName)
end

Window:OnDestroy(function()
    if Mirage.CatalogUI then
        Mirage.CatalogUI:Destroy()
    end

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
