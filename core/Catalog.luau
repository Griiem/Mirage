local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local PROXY_URL = "https://mirage.joshuanfontanaa.workers.dev"

return function()
    local Catalog = {}

    local proxy = PROXY_URL:gsub("/+$", "")

    Catalog.Hosts = {}

    if proxy ~= "" then
        table.insert(Catalog.Hosts, proxy)
    end

    table.insert(Catalog.Hosts, "https://catalog.roblox.com")

    Catalog.ActiveHost = nil

    Catalog.Categories = {
        { Name = "All", Category = 1 },
        { Name = "Accessories", Category = 11, Kind = "accessory" },
        {
            Name = "Hair",
            Category = 11,
            Keyword = "hair",
            Kind = "accessory",
            RequireKind = "accessory",
            Fallback = { Category = 1, Keyword = "hair" },
        },
        { Name = "Classic Shirts", Category = 3, Subcategory = 56, Kind = "shirt" },
        { Name = "Classic T-Shirts", Category = 3, Subcategory = 55, Kind = "tshirt" },
        { Name = "Classic Pants", Category = 3, Subcategory = 57, Kind = "pants" },
        {
            Name = "Faces",
            Category = 4,
            Kind = "face",
            AssetTypes = { [18] = true, [42] = true },
            Fallback = { Category = 1, Keyword = "face" },
        },
    }

    Catalog.Exclusives = {
        { Name = "Korblox", Category = 1, Keyword = "korblox", Kind = "bundle", RequireKind = "bundle" },
        { Name = "Fedoras", Category = 1, Keyword = "sparkle time fedora", Kind = "accessory", RequireKind = "accessory" },
        { Name = "Valkyries", Category = 1, Keyword = "valkyrie", Kind = "accessory", RequireKind = "accessory" },
        { Name = "Dominus", Category = 1, Keyword = "dominus", Kind = "accessory", RequireKind = "accessory" },
        { Name = "Domino Crown", Category = 1, Keyword = "domino crown", Kind = "accessory", RequireKind = "accessory" },
        { Name = "Headphones", Category = 1, Keyword = "clockwork headphones", Kind = "accessory", RequireKind = "accessory" },
    }

    local KIND_BY_ASSET_TYPE = {
        [2] = "tshirt",
        [8] = "accessory",
        [11] = "shirt",
        [12] = "pants",
        [18] = "face",
    }

    for assetType = 41, 47 do
        KIND_BY_ASSET_TYPE[assetType] = "accessory"
    end

    for assetType = 64, 72 do
        KIND_BY_ASSET_TYPE[assetType] = "accessory"
    end

    local TYPE_NAMES = {
        tshirt = 2,
        hat = 8,
        shirt = 11,
        pants = 12,
        face = 18,
        hairaccessory = 41,
        faceaccessory = 42,
        neckaccessory = 43,
        shoulderaccessory = 44,
        frontaccessory = 45,
        backaccessory = 46,
        waistaccessory = 47,
        tshirtaccessory = 64,
        shirtaccessory = 65,
        pantsaccessory = 66,
        jacketaccessory = 67,
        sweateraccessory = 68,
        shortsaccessory = 69,
        leftshoeaccessory = 70,
        rightshoeaccessory = 71,
        dressskirtaccessory = 72,
    }

    local function normalizeType(value)
        if type(value) == "number" then
            return value
        end

        if type(value) == "string" then
            return TYPE_NAMES[value:lower()] or tonumber(value)
        end

        return nil
    end

    local function isBundleType(value)
        return value == "Bundle" or value == 2
    end

    function Catalog.KindOf(assetType)
        local normalized = normalizeType(assetType)

        if normalized == nil then
            return nil
        end

        return KIND_BY_ASSET_TYPE[normalized]
    end

    function Catalog.Lookup(id)
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
        end)

        if not ok or type(info) ~= "table" then
            return nil, "GetProductInfo failed (" .. tostring(info) .. ")"
        end

        return {
            Id = id,
            Name = info.Name or "Unknown",
            Kind = Catalog.KindOf(info.AssetTypeId),
        }
    end

    local function fetch(url)
        local requestFn = request or http_request or (syn and syn.request)

        if type(requestFn) == "function" then
            local ok, response = pcall(requestFn, {
                Url = url,
                Method = "GET",
                Headers = { ["Accept-Language"] = "en-US,en;q=0.9" },
            })

            if ok and type(response) == "table" then
                return response.Body, response.StatusCode
            end
        end

        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)

        if ok then
            return body, 200
        end

        return nil, nil, tostring(body)
    end

    local function preview(body)
        if type(body) ~= "string" or body == "" then
            return "empty body"
        end

        local flat = body:gsub("%s+", " ")

        return flat:sub(1, 80)
    end

    local function decode(body)
        if type(body) ~= "string" then
            return nil
        end

        local ok, result = pcall(function()
            return HttpService:JSONDecode(body)
        end)

        if ok and type(result) == "table" then
            return result
        end

        return nil
    end

    local function hostList()
        local hosts = {}

        if Catalog.ActiveHost then
            table.insert(hosts, Catalog.ActiveHost)
        end

        for _, host in Catalog.Hosts do
            if host ~= Catalog.ActiveHost then
                table.insert(hosts, host)
            end
        end

        return hosts
    end

    local function requestJson(path, check)
        local failures = {}

        for _, host in hostList() do
            local body, status, err = fetch(host .. path)
            local decoded = decode(body)

            if decoded and check(decoded) then
                Catalog.ActiveHost = host
                return decoded
            end

            local reason

            if decoded and type(decoded.errors) == "table" then
                local first = decoded.errors[1]
                reason = "API error: " .. tostring(first and first.message or "unknown")
            elseif err then
                reason = err
            else
                reason = "HTTP " .. tostring(status) .. ": " .. preview(body)
            end

            local name = host:gsub("^https://", "")

            table.insert(failures, name .. " -> " .. reason)
        end

        return nil, table.concat(failures, " | ")
    end

    local function looksLikeImage(body)
        if type(body) ~= "string" or #body < 16 then
            return false
        end

        if body:sub(2, 4) == "PNG" then
            return true
        end

        return body:byte(1) == 255 and body:byte(2) == 216
    end

    function Catalog.FetchAsset(id)
        local urls = {}

        if proxy ~= "" then
            table.insert(urls, proxy .. "/v1/asset?id=" .. tostring(id))
        end

        table.insert(urls, "https://assetdelivery.roblox.com/v1/asset/?id=" .. tostring(id))

        local failures = {}

        for _, url in urls do
            local body, status, err = fetch(url)

            if looksLikeImage(body) then
                return body
            end

            local name = url:match("^https://([^/]+)")

            table.insert(failures, tostring(name) .. " -> " .. (err or ("HTTP " .. tostring(status) .. ": " .. preview(body))))
        end

        return nil, table.concat(failures, " | ")
    end

    function Catalog.BundleAssets(id)
        local decoded, reason = requestJson("/v1/bundles/" .. tostring(id) .. "/details", function(result)
            return type(result.items) == "table"
        end)

        if not decoded then
            return nil, reason
        end

        local ids = {}

        for _, item in decoded.items do
            if item.type == "Asset" and type(item.id) == "number" then
                table.insert(ids, item.id)
            end
        end

        if #ids == 0 then
            return nil, "bundle has no asset items"
        end

        return ids
    end

    local function buildItem(raw)
        if type(raw.id) ~= "number" then
            return nil
        end

        local isBundle = isBundleType(raw.itemType)
        local kind

        if isBundle then
            kind = "bundle"
        else
            kind = Catalog.KindOf(raw.assetType)
        end

        return {
            Id = raw.id,
            Name = raw.name or "Unknown",
            Kind = kind,
            IsBundle = isBundle,
        }
    end

    local function accepts(item, raw, options)
        if options.AssetTypes then
            if item.IsBundle then
                return false
            end

            local normalized = normalizeType(raw.assetType)

            if normalized ~= nil and not options.AssetTypes[normalized] then
                return false
            end
        end

        if options.RequireKind == "bundle" then
            return item.IsBundle
        end

        if options.RequireKind then
            if item.IsBundle then
                return false
            end

            if item.Kind ~= nil and item.Kind ~= options.RequireKind then
                return false
            end
        end

        return true
    end

    function Catalog.Search(options)
        local params = {
            "Category=" .. tostring(options.Category or 1),
            "Limit=30",
            "SortType=0",
            "SortAggregation=5",
        }

        if options.Subcategory then
            table.insert(params, "Subcategory=" .. tostring(options.Subcategory))
        end

        if options.Keyword and options.Keyword ~= "" then
            table.insert(params, "Keyword=" .. HttpService:UrlEncode(options.Keyword))
        end

        local filtering = options.AssetTypes ~= nil or options.RequireKind ~= nil
        local maxPages = filtering and 4 or 1
        local collected = {}
        local cursor = options.Cursor
        local lastError

        for _ = 1, maxPages do
            local list = table.clone(params)

            if cursor and cursor ~= "" then
                table.insert(list, "Cursor=" .. HttpService:UrlEncode(cursor))
            end

            local decoded, failure = requestJson(
                "/v1/search/items/details?" .. table.concat(list, "&"),
                function(result)
                    return type(result.data) == "table"
                end
            )

            if not decoded then
                lastError = failure
                break
            end

            for _, raw in decoded.data do
                local item = buildItem(raw)

                if item and accepts(item, raw, options) then
                    table.insert(collected, item)
                end
            end

            cursor = decoded.nextPageCursor

            if not cursor or cursor == "" or #collected >= 12 then
                break
            end
        end

        if #collected == 0 and lastError then
            return nil, lastError
        end

        if cursor == "" then
            cursor = nil
        end

        return {
            Items = collected,
            NextCursor = cursor,
        }
    end

    return Catalog
end
