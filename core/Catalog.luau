local HttpService = game:GetService("HttpService")

return function()
    local Catalog = {}

    Catalog.Hosts = {
        "https://catalog.roblox.com",
        "https://catalog.roproxy.com",
    }

    Catalog.ActiveHost = nil

    Catalog.Categories = {
        { Name = "All", Category = 1 },
        { Name = "Accessories", Category = 11, Kind = "accessory" },
        { Name = "Hair", Category = 11, Subcategory = 20, Kind = "accessory" },
        { Name = "Classic Shirts", Category = 3, Subcategory = 56, Kind = "shirt" },
        { Name = "Classic T-Shirts", Category = 3, Subcategory = 55, Kind = "tshirt" },
        { Name = "Classic Pants", Category = 3, Subcategory = 57, Kind = "pants" },
        { Name = "Faces", Category = 4, Subcategory = 10, Kind = "face" },
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

    local function buildResult(decoded)
        local items = {}

        for _, item in decoded.data do
            if type(item.id) == "number" then
                local kind

                if item.itemType == nil or item.itemType == "Asset" then
                    kind = Catalog.KindOf(item.assetType)
                end

                table.insert(items, {
                    Id = item.id,
                    Name = item.name or "Unknown",
                    Kind = kind,
                    ItemType = item.itemType,
                    Creator = item.creatorName,
                })
            end
        end

        return {
            Items = items,
            NextCursor = decoded.nextPageCursor,
        }
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

        if options.Cursor and options.Cursor ~= "" then
            table.insert(params, "Cursor=" .. HttpService:UrlEncode(options.Cursor))
        end

        local path = "/v1/search/items/details?" .. table.concat(params, "&")

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
                return buildResult(decoded)
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

    return Catalog
end
