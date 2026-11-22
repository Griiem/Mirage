local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

return function(RAW_URL)
    local Skins = {
        Enabled = true,
        Alive = true,
        Index = {},
        Assets = {},
        Applied = setmetatable({}, { __mode = "k" }),
        Watched = {},
        Tokens = {},
        Connections = {},
        Counter = 0,
    }

    local CACHE_ROOT = "Mirage"
    local CACHE = "Mirage/cache"

    local SLOTS = {
        shirt = { Class = "Shirt", Prop = "ShirtTemplate" },
        pants = { Class = "Pants", Prop = "PantsTemplate" },
        tshirt = { Class = "ShirtGraphic", Prop = "Graphic" },
    }

    local HasFs = type(writefile) == "function"
        and type(getcustomasset) == "function"
        and type(isfolder) == "function"
        and type(makefolder) == "function"

    Skins.HasFs = HasFs

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(Skins.Connections, c)
        return c
    end

    local function prepareCache()
        if not HasFs then
            return
        end

        pcall(function()
            if not isfolder(CACHE_ROOT) then
                makefolder(CACHE_ROOT)
            end

            if not isfolder(CACHE) then
                makefolder(CACHE)
            end

            if type(listfiles) == "function" and type(delfile) == "function" then
                for _, f in listfiles(CACHE) do
                    pcall(delfile, f)
                end
            end
        end)
    end

    local function fetchIndex()
        local ok, result = pcall(function()
            return HttpService:JSONDecode(
                game:HttpGet(RAW_URL .. "skins/index.json?t=" .. os.time())
            )
        end)

        if ok and type(result) == "table" then
            return result
        end

        return nil
    end

    local function download(userId, kind, fileName)
        if not HasFs or type(fileName) ~= "string" then
            return nil
        end

        local url = ("%sskins/%s/%s?t=%d"):format(RAW_URL, userId, fileName, os.time())

        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)

        if not ok or type(body) ~= "string" or body:sub(2, 4) ~= "PNG" then
            return nil
        end

        Skins.Counter += 1

        local path = ("%s/%s_%s_%d.png"):format(CACHE, userId, kind, Skins.Counter)

        if not pcall(writefile, path, body) then
            return nil
        end

        local gotAsset, asset = pcall(getcustomasset, path)

        if gotAsset and asset then
            return asset
        end

        return nil
    end

    local function loadAssets(userId)
        local key = tostring(userId)

        if Skins.Assets[key] then
            return Skins.Assets[key]
        end

        local entry = Skins.Index[key]

        if type(entry) ~= "table" then
            return nil
        end

        local assets = {}

        for kind in SLOTS do
            local asset = download(key, kind, entry[kind])

            if asset then
                assets[kind] = asset
            end
        end

        Skins.Assets[key] = assets

        return assets
    end

    local function restore(character)
        local undo = Skins.Applied[character]

        if not undo then
            return
        end

        Skins.Applied[character] = nil

        for i = #undo, 1, -1 do
            pcall(undo[i])
        end
    end

    local function apply(player)
        local character = player.Character

        if not character or not Skins.Enabled or not Skins.Alive then
            return
        end

        local assets = loadAssets(player.UserId)

        if not assets or next(assets) == nil then
            return
        end

        if player.Character ~= character or not Skins.Enabled or not Skins.Alive then
            return
        end

        restore(character)

        local undo = {}
        Skins.Applied[character] = undo

        for kind, slot in SLOTS do
            local asset = assets[kind]

            if asset then
                local inst = character:FindFirstChildOfClass(slot.Class)

                if inst then
                    local old = inst[slot.Prop]

                    inst[slot.Prop] = asset

                    table.insert(undo, function()
                        if inst.Parent then
                            inst[slot.Prop] = old
                        end
                    end)
                else
                    inst = Instance.new(slot.Class)
                    inst[slot.Prop] = asset
                    inst.Parent = character

                    table.insert(undo, function()
                        inst:Destroy()
                    end)
                end
            end
        end
    end

    local function waitAppearance(player)
        local tries = 0

        while Skins.Alive and tries < 50 do
            local ok, ready = pcall(function()
                return player:HasAppearanceLoaded()
            end)

            if not ok or ready then
                return
            end

            tries += 1
            task.wait(0.2)
        end
    end

    local function schedule(player)
        local token = (Skins.Tokens[player] or 0) + 1
        Skins.Tokens[player] = token

        task.spawn(function()
            local character = player.Character

            if not character then
                return
            end

            waitAppearance(player)

            if Skins.Tokens[player] ~= token or player.Character ~= character then
                return
            end

            apply(player)

            task.wait(3)

            if Skins.Tokens[player] ~= token or player.Character ~= character then
                return
            end

            apply(player)
        end)
    end

    local function watch(player)
        if Skins.Watched[player] then
            return
        end

        if not Skins.Index[tostring(player.UserId)] then
            return
        end

        Skins.Watched[player] = true

        connect(player.CharacterAdded, function()
            schedule(player)
        end)

        if player.Character then
            schedule(player)
        end
    end

    function Skins:Count()
        local n = 0

        for _, player in Players:GetPlayers() do
            if Skins.Index[tostring(player.UserId)] then
                n += 1
            end
        end

        return n
    end

    function Skins:Refresh()
        local index = fetchIndex()

        if not index then
            return false
        end

        Skins.Index = index
        table.clear(Skins.Assets)

        for _, player in Players:GetPlayers() do
            if Skins.Index[tostring(player.UserId)] then
                if Skins.Watched[player] then
                    schedule(player)
                else
                    watch(player)
                end
            elseif player.Character then
                restore(player.Character)
            end
        end

        return true
    end

    function Skins:SetEnabled(state)
        Skins.Enabled = state

        if state then
            for _, player in Players:GetPlayers() do
                if Skins.Index[tostring(player.UserId)] then
                    if Skins.Watched[player] then
                        schedule(player)
                    else
                        watch(player)
                    end
                end
            end

            return
        end

        local list = {}

        for character in Skins.Applied do
            table.insert(list, character)
        end

        for _, character in list do
            restore(character)
        end
    end

    function Skins:Start()
        prepareCache()

        connect(Players.PlayerAdded, function(player)
            watch(player)
        end)

        connect(Players.PlayerRemoving, function(player)
            Skins.Watched[player] = nil
            Skins.Tokens[player] = nil
        end)

        return Skins:Refresh()
    end

    function Skins:Cleanup()
        Skins.Alive = false

        for _, c in Skins.Connections do
            if c.Connected then
                c:Disconnect()
            end
        end

        table.clear(Skins.Connections)

        local list = {}

        for character in Skins.Applied do
            table.insert(list, character)
        end

        for _, character in list do
            restore(character)
        end

        table.clear(Skins.Watched)
        table.clear(Skins.Tokens)
        table.clear(Skins.Assets)
    end

    return Skins
end
