local enable = GetConvar('qbx:enableVehiclePersistence', 'false') == 'true'
local full = GetConvar('qbx:vehiclePersistenceType', 'semi') == 'full'

if not enable then return end

local cachedProps
local netId
local vehicle
local seat

local vehicleEntries = {}
local spawnRequested = {}
local lastCheckTime = 0
local CHECK_INTERVAL = 2000
local watchedKeys = {
    'bodyHealth',
    'engineHealth',
    'tankHealth',
    'fuelLevel',
    'oilLevel',
    'dirtLevel',
    'windows',
    'doors',
    'tyres',
}

local function calculateDiff(tbl1, tbl2)
    local diff = {}
    local hasChanged = false

    for i = 1, #watchedKeys do
        local key = watchedKeys[i]
        local val1 = tbl1[key]
        local val2 = tbl2[key]

        local bothTables = type(val1) == "table" and type(val2) == "table"
        local equal = (bothTables and lib.table.matches(val1, val2)) or (val1 == val2)

        if not equal then
            diff[key] = val2 == nil and 'deleted' or val2
            hasChanged = true
        end
    end

    return diff, hasChanged
end

local function sendPropsDiff()
    if not Entity(vehicle).state.persisted then return end

    if full then TriggerServerEvent('qbx_core:server:vehiclePositionChanged', netId) end

    local newProps = lib.getVehicleProperties(vehicle)
    if not cachedProps then
        cachedProps = newProps
        return
    end

    local diff, hasChanged = calculateDiff(cachedProps, newProps)
    cachedProps = newProps
    if not hasChanged then return end

    TriggerServerEvent('qbx_core:server:vehiclePropsChanged', netId, diff)
end

local function createVehicleEntries(vehicles)
    for id, coords in pairs(vehicles) do
        if not vehicleEntries[id] then
            local entry = {
                coords = coords,
                radius = 75.0,
                id = id
            }
            lib.grid.addEntry(entry)
            vehicleEntries[id] = entry
        end
    end
end

local function checkNearbyVehicles()
    local currentTime = GetGameTimer()
    if (currentTime - lastCheckTime) < CHECK_INTERVAL then
        return
    end
    lastCheckTime = currentTime

    if not cache.ped or not DoesEntityExist(cache.ped) then return end

    local playerCoords = GetEntityCoords(cache.ped)
    local nearbyEntries = lib.grid.getNearbyEntries(playerCoords, function(entry)
        return entry.id and vehicleEntries[entry.id] and not spawnRequested[entry.id]
    end)

    for i = 1, #nearbyEntries do
        local entry = nearbyEntries[i]
        if entry.id and vehicleEntries[entry.id] and not spawnRequested[entry.id] then
            local distance = #(vec3(playerCoords.x, playerCoords.y, playerCoords.z) - vec3(entry.coords.x, entry.coords.y, entry.coords.z))
            if distance <= entry.radius then
                TriggerServerEvent('qbx_core:server:spawnVehicle', entry.id, entry.coords)
                spawnRequested[entry.id] = true
            end
        end
    end
end

lib.onCache('seat', function(newSeat)
    if newSeat == -1 then
        seat = -1
        vehicle = cache.vehicle
        netId = NetworkGetNetworkIdFromEntity(vehicle)
        CreateThread(function()
            while seat == -1 do
                sendPropsDiff()
                Wait(10000)
            end
        end)
    elseif seat == -1 then
        seat = nil
        sendPropsDiff()
        vehicle = nil
        netId = nil
    end
end)

CreateThread(function()
    Wait(1000)

    local vehicles = lib.callback.await('qbx_core:server:getVehiclesToSpawn', 2500)
    if not vehicles then return end

    createVehicleEntries(vehicles)

    if next(vehicleEntries) then
        CreateThread(function()
            while next(vehicleEntries) do
                checkNearbyVehicles()
                Wait(CHECK_INTERVAL)
            end
        end)
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local vehicles = lib.callback.await('qbx_core:server:getVehiclesToSpawn', 2500)
    if not vehicles then return end

    createVehicleEntries(vehicles)

    if next(vehicleEntries) then
        CreateThread(function()
            while next(vehicleEntries) do
                checkNearbyVehicles()
                Wait(CHECK_INTERVAL)
            end
        end)
    end
end)

RegisterNetEvent('qbx_core:client:removeVehZone', function(id)
    if not vehicleEntries[id] then return end

    lib.grid.removeEntry(vehicleEntries[id])
    vehicleEntries[id] = nil
    spawnRequested[id] = nil
end)
