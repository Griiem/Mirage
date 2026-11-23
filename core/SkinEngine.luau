local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")

return function(RAW_URL)
    local Skins = {
        Enabled = true,
        Alive = true,
        Index = {},
        Assets = {},
        Status = {},
        Objects = {},
        Textures = {},
        BundleCache = {},
        Overlays = {},
        Catalog = nil,
        LocalLoadout = nil,
        Applied = setmetatable({}, { __mode = "k" }),
        Watched = {},
        Tokens = {},
        Connections = {},
        Counter = 0,
    }

    local CACHE_ROOT = "Mirage"
    local CACHE = "Mirage/cache"

    local KINDS = { "shirt", "pants", "tshirt", "face" }

    local SLOTS = {
        shirt = { Class = "Shirt", Prop = "ShirtTemplate" },
        pants = { Class = "Pants", Prop = "PantsTemplate" },
        tshirt = { Class = "ShirtGraphic", Prop = "Graphic" },
    }

    local CATALOG_CLASS = {
        shirt = { "Shirt", "ShirtTemplate" },
        pants = { "Pants", "PantsTemplate" },
        tshirt = { "ShirtGraphic", "Graphic" },
        face = { "Decal", "Texture" },
    }

    local PART_NAMES = {
        R15 = {
            UpperTorso = true,
            LowerTorso = true,
            LeftUpperArm = true,
            LeftLowerArm = true,
            LeftHand = true,
            RightUpperArm = true,
            RightLowerArm = true,
            RightHand = true,
            LeftUpperLeg = true,
            LeftLowerLeg = true,
            LeftFoot = true,
            RightUpperLeg = true,
            RightLowerLeg = true,
            RightFoot = true,
        },
        R6 = {
            Torso = true,
            ["Left Arm"] = true,
            ["Right Arm"] = true,
            ["Left Leg"] = true,
            ["Right Leg"] = true,
        },
    }

    local HasFs = type(writefile) == "function"
        and type(getcustomasset) == "function"
        and type(isfolder) == "function"
        and type(makefolder) == "function"

    Skins.HasFs = HasFs

    local function log(...)
        warn("[Mirage]", ...)
    end

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(Skins.Connections, c)
        return c
    end

    local function entryFor(player)
        local base = Skins.Index[tostring(player.UserId)]

        if type(base) ~= "table" then
            base = nil
        end

        if player ~= Players.LocalPlayer then
            return base
        end

        local merged = {}

        if base then
            for key, value in base do
                merged[key] = value
            end
        end

        if Skins.LocalLoadout then
            for key, value in Skins.LocalLoadout do
                merged[key] = value
            end
        end

        if next(merged) == nil then
            return nil
        end

        return merged
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

        log("Failed to read skins/index.json:", tostring(result))

        return nil
    end

    local function ensureCache()
        pcall(function()
            if not isfolder(CACHE_ROOT) then
                makefolder(CACHE_ROOT)
            end

            if not isfolder(CACHE) then
                makefolder(CACHE)
            end
        end)
    end

    local function toCustomAsset(tag, body)
        if not HasFs then
            return nil, "executor has no file functions"
        end

        ensureCache()

        Skins.Counter += 1

        local path = ("%s/%s_%d.png"):format(CACHE, tag, Skins.Counter)

        local wrote, writeErr = pcall(writefile, path, body)

        if not wrote then
            return nil, "writefile failed (" .. tostring(writeErr) .. ")"
        end

        local gotAsset, asset = pcall(getcustomasset, path)

        if not gotAsset or not asset then
            return nil, "getcustomasset failed (" .. tostring(asset) .. ")"
        end

        return asset
    end

    local function download(userId, kind, fileName)
        if type(fileName) ~= "string" then
            return nil, "no file name in index.json"
        end

        local url = ("%sskins/%s/%s?t=%d"):format(RAW_URL, userId, fileName, os.time())

        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)

        if not ok then
            return nil, "HttpGet failed for " .. url .. " (" .. tostring(body) .. ")"
        end

        if type(body) ~= "string" or body:sub(2, 4) ~= "PNG" then
            return nil, "not a valid PNG at " .. url
        end

        return toCustomAsset(userId .. "_" .. kind, body)
    end

    local function findClass(objects, className)
        for _, obj in objects do
            if typeof(obj) == "Instance" then
                if obj:IsA(className) then
                    return obj
                end

                local inner = obj:FindFirstChildWhichIsA(className, true)

                if inner then
                    return inner
                end
            end
        end

        return nil
    end

    local function loadObject(id, className)
        local cacheKey = className .. ":" .. tostring(id)

        if Skins.Objects[cacheKey] then
            return Skins.Objects[cacheKey]
        end

        local found
        local reason = "asset " .. tostring(id) .. " could not be loaded"

        local ok, objects = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(id))
        end)

        if ok and type(objects) == "table" then
            found = findClass(objects, className)

            if not found then
                reason = "asset " .. tostring(id) .. " has no " .. className
            end
        else
            reason = "GetObjects failed (" .. tostring(objects) .. ")"
        end

        if not found then
            local okLoad, model = pcall(function()
                return InsertService:LoadAsset(tonumber(id))
            end)

            if okLoad and model then
                found = model:FindFirstChildWhichIsA(className, true)

                if found then
                    found.Parent = nil
                end

                model:Destroy()
            end
        end

        if found then
            Skins.Objects[cacheKey] = found
            return found
        end

        return nil, reason
    end

    local function loadCatalogItem(userId, kind, id)
        local info = CATALOG_CLASS[kind]
        local obj, reason = loadObject(id, info[1])

        if not obj then
            return nil, reason
        end

        local template = obj[info[2]]

        if type(template) ~= "string" or template == "" then
            return nil, "asset " .. tostring(id) .. " has no " .. info[2]
        end

        local templateId = template:match("id=(%d+)") or template:match("rbxassetid://(%d+)")
        local catalog = Skins.Catalog

        if templateId and catalog and catalog.FetchAsset then
            local cacheKey = kind .. ":" .. templateId

            if Skins.Textures[cacheKey] then
                return Skins.Textures[cacheKey], "download"
            end

            local body, fetchReason = catalog.FetchAsset(templateId)

            if body then
                local asset, assetReason = toCustomAsset(userId .. "_" .. kind, body)

                if asset then
                    Skins.Textures[cacheKey] = asset
                    return asset, "download"
                end

                log(kind, id, assetReason)
            else
                log(kind, id, "texture download failed, using the asset instance:", tostring(fetchReason))
            end
        end

        return obj, "instance"
    end

    local function resolveBundle(id)
        if Skins.BundleCache[id] then
            return Skins.BundleCache[id]
        end

        local catalog = Skins.Catalog

        if not catalog or not catalog.BundleAssets then
            return nil, "catalog module is not loaded"
        end

        local ids, reason = catalog.BundleAssets(id)

        if ids then
            Skins.BundleCache[id] = ids
        end

        return ids, reason
    end

    local function loadAssets(player)
        local key = tostring(player.UserId)

        if Skins.Assets[key] then
            return Skins.Assets[key]
        end

        local entry = entryFor(player)

        if not entry then
            return nil
        end

        local status = { Listed = {}, Loaded = {}, Failed = {}, Applied = {} }
        Skins.Status[key] = status

        local assets = {}

        for _, kind in KINDS do
            local value = entry[kind]

            if value ~= nil then
                table.insert(status.Listed, kind)

                local result, detail

                if type(value) == "string" then
                    result, detail = download(key, kind, value)
                elseif type(value) == "number" then
                    result, detail = loadCatalogItem(key, kind, value)
                else
                    detail = "unsupported value in the entry"
                end

                if result then
                    assets[kind] = result
                    table.insert(status.Loaded, kind .. (type(value) == "number" and (" (" .. tostring(detail) .. ")") or ""))
                else
                    status.Failed[kind] = tostring(detail)
                    log(key, kind, tostring(detail))
                end
            end
        end

        if type(entry.accessories) == "table" then
            local list = {}

            for _, id in entry.accessories do
                table.insert(status.Listed, "accessory")

                local obj, reason = loadObject(id, "Accessory")

                if obj then
                    table.insert(list, obj)
                    table.insert(status.Loaded, "accessory")
                else
                    status.Failed["accessory " .. tostring(id)] = reason
                    log(key, "accessory", reason)
                end
            end

            if #list > 0 then
                assets.accessories = list
            end
        end

        if type(entry.bundles) == "table" then
            local roots = {}

            for _, bundleId in entry.bundles do
                table.insert(status.Listed, "bundle")

                local assetIds, reason = resolveBundle(bundleId)

                if assetIds then
                    local count = 0

                    for _, assetId in assetIds do
                        local root = loadObject(assetId, "Instance")

                        if root then
                            table.insert(roots, root)
                            count += 1
                        end
                    end

                    if count > 0 then
                        table.insert(status.Loaded, "bundle " .. tostring(bundleId))
                    else
                        status.Failed["bundle " .. tostring(bundleId)] = "none of its assets could be loaded"
                        log(key, "bundle", bundleId, "none of its assets could be loaded")
                    end
                else
                    status.Failed["bundle " .. tostring(bundleId)] = tostring(reason)
                    log(key, "bundle", bundleId, tostring(reason))
                end
            end

            if #roots > 0 then
                assets.bundleRoots = roots
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

    local function setProperty(undo, inst, prop, value, created)
        local old = inst[prop]

        inst[prop] = value

        local guard = inst:GetPropertyChangedSignal(prop):Connect(function()
            if Skins.Enabled and Skins.Alive and inst[prop] ~= value then
                inst[prop] = value
            end
        end)

        table.insert(undo, function()
            guard:Disconnect()

            if created then
                inst:Destroy()
            elseif inst.Parent then
                inst[prop] = old
            end
        end)
    end

    local function replaceChildren(undo, parent, predicate, clone)
        for _, child in parent:GetChildren() do
            if predicate(child) then
                child.Parent = nil

                table.insert(undo, function()
                    child.Parent = parent
                end)
            end
        end

        clone.Parent = parent

        table.insert(undo, function()
            clone:Destroy()
        end)
    end

    local function templateParts(root, isR15)
        local names = isR15 and PART_NAMES.R15 or PART_NAMES.R6
        local folderNames = isR15 and { "R15ArtistIntent", "R15Fixed", "R15" } or { "R6" }
        local source = root

        for _, folderName in folderNames do
            local folder = root:FindFirstChild(folderName, true)

            if folder then
                source = folder
                break
            end
        end

        local parts = {}

        if source:IsA("BasePart") and names[source.Name] then
            table.insert(parts, source)
        end

        for _, descendant in source:GetDescendants() do
            if descendant:IsA("BasePart") and names[descendant.Name] then
                table.insert(parts, descendant)
            end
        end

        return parts
    end

    local function overlay(character, undo, template, target)
        local clone = template:Clone()

        for _, descendant in clone:GetDescendants() do
            if descendant:IsA("Attachment")
                or descendant:IsA("JointInstance")
                or descendant:IsA("Constraint")
                or descendant:IsA("BaseScript") then

                descendant:Destroy()
            end
        end

        clone.Name = "Mirage_" .. template.Name:gsub("%s", "")
        clone.Anchored = true
        clone.CanCollide = false
        clone.CanTouch = false
        clone.CanQuery = false
        clone.Massless = true
        clone.CFrame = target.CFrame
        clone.Parent = character

        setProperty(undo, target, "Transparency", 1, false)

        table.insert(undo, function()
            clone:Destroy()
        end)

        table.insert(Skins.Overlays, { Clone = clone, Target = target })
    end

    local function updateOverlays()
        for index = #Skins.Overlays, 1, -1 do
            local pair = Skins.Overlays[index]

            if pair.Clone.Parent and pair.Target.Parent then
                pair.Clone.CFrame = pair.Target.CFrame
            else
                pair.Clone:Destroy()
                table.remove(Skins.Overlays, index)
            end
        end
    end

    local function apply(player)
        local character = player.Character

        if not character or not Skins.Enabled or not Skins.Alive then
            return
        end

        local assets = loadAssets(player) or {}

        if player.Character ~= character or not Skins.Enabled or not Skins.Alive then
            return
        end

        local entry = entryFor(player)
        local headless = entry ~= nil and entry.headless == true
        local hideOwn = entry ~= nil and entry.clearAccessories == true

        if next(assets) == nil and not headless and not hideOwn then
            restore(character)
            return
        end

        restore(character)

        local undo = {}
        Skins.Applied[character] = undo

        local status = Skins.Status[tostring(player.UserId)]

        local function mark(name)
            if status then
                table.insert(status.Applied, name)
            end
        end

        if status then
            table.clear(status.Applied)
        end

        for kind, slot in SLOTS do
            local asset = assets[kind]

            if asset then
                if typeof(asset) == "Instance" then
                    replaceChildren(undo, character, function(child)
                        return child:IsA(slot.Class)
                    end, asset:Clone())
                else
                    local inst = character:FindFirstChildOfClass(slot.Class)
                    local created = false

                    if not inst then
                        inst = Instance.new(slot.Class)
                        inst.Parent = character
                        created = true
                    end

                    setProperty(undo, inst, slot.Prop, asset, created)
                end

                mark(kind)
            end
        end

        if assets.face then
            local head = character:FindFirstChild("Head")

            if head then
                if typeof(assets.face) == "Instance" then
                    local clone = assets.face:Clone()
                    clone.Name = "face"

                    replaceChildren(undo, head, function(child)
                        return child:IsA("Decal") and child.Name == "face"
                    end, clone)
                else
                    local decal = head:FindFirstChild("face")
                    local created = false

                    if not (decal and decal:IsA("Decal")) then
                        decal = Instance.new("Decal")
                        decal.Name = "face"
                        decal.Face = Enum.NormalId.Front
                        decal.Parent = head
                        created = true
                    end

                    setProperty(undo, decal, "Texture", assets.face, created)
                end

                mark("face")
            end
        end

        if headless then
            local head = character:FindFirstChild("Head")

            if head and head:IsA("BasePart") then
                setProperty(undo, head, "Transparency", 1, false)

                for _, child in head:GetChildren() do
                    if child:IsA("Decal") then
                        setProperty(undo, child, "Transparency", 1, false)
                    end
                end

                mark("headless")
            end
        end

        if assets.bundleRoots then
            local isR15 = character:FindFirstChild("UpperTorso") ~= nil
            local used = {}

            for _, root in assets.bundleRoots do
                for _, template in templateParts(root, isR15) do
                    local target = character:FindFirstChild(template.Name)

                    if target and target:IsA("BasePart") and not used[template.Name] then
                        used[template.Name] = true
                        overlay(character, undo, template, target)
                        mark("bundle part " .. template.Name)
                    end
                end
            end
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if humanoid and hideOwn then
            for _, child in character:GetChildren() do
                if child:IsA("Accessory") then
                    child.Parent = nil

                    table.insert(undo, function()
                        child.Parent = character
                    end)
                end
            end
        end

        if humanoid and assets.accessories then
            for _, template in assets.accessories do
                local clone = template:Clone()

                local added = pcall(function()
                    humanoid:AddAccessory(clone)
                end)

                if added then
                    table.insert(undo, function()
                        clone:Destroy()
                    end)

                    mark("accessory")
                else
                    clone:Destroy()
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

    local function safeApply(player)
        local ok, err = pcall(apply, player)

        if not ok then
            log("Apply error:", tostring(err))
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

            safeApply(player)

            task.wait(3)

            if Skins.Tokens[player] ~= token or player.Character ~= character then
                return
            end

            safeApply(player)
        end)
    end

    local function watch(player)
        if Skins.Watched[player] then
            return
        end

        if not entryFor(player) then
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

    function Skins:SetLocalLoadout(loadout)
        Skins.LocalLoadout = loadout

        local player = Players.LocalPlayer
        local key = tostring(player.UserId)

        Skins.Assets[key] = nil
        Skins.Status[key] = nil

        if not Skins.Enabled then
            return
        end

        if Skins.Watched[player] then
            schedule(player)
        else
            watch(player)
        end
    end

    function Skins:Report(player)
        local key = tostring(player.UserId)

        if not entryFor(player) then
            return "No entry for user ID " .. key .. " in skins/index.json and no local loadout"
        end

        local status = Skins.Status[key]

        if not status then
            return "Entry found for " .. key .. " but no load was attempted yet (character not loaded?)"
        end

        local lines = {
            "Listed: " .. (#status.Listed > 0 and table.concat(status.Listed, ", ") or "none"),
            "Loaded: " .. (#status.Loaded > 0 and table.concat(status.Loaded, ", ") or "none"),
            "Applied: " .. (#status.Applied > 0 and table.concat(status.Applied, ", ") or "none"),
        }

        for kind, reason in status.Failed do
            table.insert(lines, "Failed " .. kind .. ": " .. reason)
        end

        return table.concat(lines, " | ")
    end

    function Skins:Count()
        local n = 0

        for _, player in Players:GetPlayers() do
            if entryFor(player) then
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
        table.clear(Skins.Status)

        for _, player in Players:GetPlayers() do
            if entryFor(player) then
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
                if entryFor(player) then
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

    function Skins:Prepare()
        prepareCache()
    end

    function Skins:Start()
        connect(RunService.RenderStepped, updateOverlays)

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

        table.clear(Skins.Overlays)
        table.clear(Skins.Watched)
        table.clear(Skins.Tokens)
        table.clear(Skins.Assets)
        table.clear(Skins.Status)
    end

    return Skins
end
