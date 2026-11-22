local HttpService = game:GetService("HttpService")

local _version = "1.6.66"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. _version .. "/main.lua"))()

local OWNER = "Griiem"
local REPO = "Kraneos.Wtf"
local BRANCH = "main"

local RAW_URL = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(OWNER, REPO, BRANCH)
local API_URL = ("https://api.github.com/repos/%s/%s/contents/tabs/"):format(OWNER, REPO)

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
