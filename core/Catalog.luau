local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local PROXY_URL = "https://mirage.joshuanfontanaa.workers.dev"

return function()
    local Catalog = {}

    Catalog.Hosts = {}

    if PROXY_URL ~= "" then
        table.insert(Catalog.Hosts, (PROXY_URL:gsub("/+$", "")))
    end

    table.insert(Catalog.Hosts, "https://catalog.roblox.com")

    Catalog.ActiveHost = nil

    Catalog.Categories = {
        { Name = "All", Category = 1 },
        { Name = "Accessories", Category = 11, Kind = "accessory" },
        { Name = "Hair", Category = 1, Keyword = "hair", Kind = "accessory", AssetTypes = { [41] = true } },
        { Name = "Classic Shirts", Category = 3, Subcategory = 56, Kind = "shirt" },
        { Name = "Classic T-Shirts", Category = 3, Subcategory = 55, Kind = "tshirt" },
        { Name = "Classic Pants", Category = 3, Subcategory = 57, Kind = "pants" },
        { Name = "Faces", Category = 1, Keyword = "face", Kind = "face", AssetTypes = { [18] = true } },
    }

    Catalog.Exclusives = {
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

    function Catalog.KindOf(assetType)
        return KIND_BY_ASSET_TYPE[assetType]
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
            local ok, response = pcall(requestFn, { Url = url, Method = "GET" })

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

    local function requestPage(params, cursor)
        local list = table.clone(params)

        if cursor and cursor ~= "" then
            table.insert(list, "Cursor=" .. HttpService:UrlEncode(cursor))
        end

        local path = "/v1/search/items/details?" .. table.concat(list, "&")

        local hosts = {}

        if Catalog.ActiveHost then
            table.insert(hosts, Catalog.ActiveHost)
        end

        for _, host in Catalog.Hosts do
            if host ~= Catalog.ActiveHost then
                table.insert(hosts, host)
            end
        end

        local failures = {}

        for _, host in hosts do
            local body, status, err = fetch(host .. path)
            local decoded

            if type(body) == "string" then
                local ok, result = pcall(function()
                    return HttpService:JSONDecode(body)
                end)

                if ok and type(result) == "table" then
                    decoded = result
                end
            end

            if decoded and type(decoded.data) == "table" then
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

    local function buildItem(raw)
        if type(raw.id) ~= "number" then
            return nil
        end

        local isBundle = raw.itemType == "Bundle"
        local kind

        if not isBundle then
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

            if raw.assetType ~= nil and not options.AssetTypes[raw.assetType] then
                return false
            end
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
            local decoded, failure = requestPage(params, cursor)

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
