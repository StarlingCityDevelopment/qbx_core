local enable = GetConvar('qbx:enableVehiclePersistence', 'false') == 'true'
local full = GetConvar('qbx:vehiclePersistenceType', 'semi') == 'full'

if not enable then return end

local cachedProps
local netId
local vehicle
local seat

local vehicleEntries = {}
local spawnedVehicles = {}
local SPAWN_DISTANCE = 75.0
local CHECK_INTERVAL = 1000

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

---Calculates the difference in values of two tables for the watched keys.
---If the second table does not have a value that the first table has, it will be marked 'deleted'.
---@param tbl1 table
---@param tbl2 table
---@return table diff
---@return boolean hasChanged if diff table is not empty
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

---Adds vehicles to the grid for spatial lookup
---@param vehicles table<number, vector4>
local function addVehiclesToGrid(vehicles)
    for id, coords in pairs(vehicles) do
        if not vehicleEntries[id] then
            local entry = {
                coords = vec3(coords.x, coords.y, coords.z),
                radius = SPAWN_DISTANCE,
                id = id,
                spawnCoords = coords,
            }
            vehicleEntries[id] = entry
            lib.grid.addEntry(entry)
        end
    end
end

---Removes a vehicle from the grid
---@param id number
local function removeVehicleFromGrid(id)
    local entry = vehicleEntries[id]
    if entry then
        lib.grid.removeEntry(entry)
        vehicleEntries[id] = nil
        spawnedVehicles[id] = nil
    end
end

local function checkNearbyVehicles()
    local playerCoords = GetEntityCoords(cache.ped)
    local nearbyEntries = lib.grid.getNearbyEntries(playerCoords, function(entry)
        local dist = #(playerCoords - entry.coords)
        return dist <= SPAWN_DISTANCE and not spawnedVehicles[entry.id]
    end)

    for i = 1, #nearbyEntries do
        local entry = nearbyEntries[i]
        spawnedVehicles[entry.id] = true
        TriggerServerEvent('qbx_core:server:spawnVehicle', entry.id, entry.spawnCoords)
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

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local vehicles = lib.callback.await('qbx_core:server:getVehiclesToSpawn', 2500)
    if not vehicles then return end

    addVehiclesToGrid(vehicles)

    CreateThread(function()
        while LocalPlayer.state.isLoggedIn and next(vehicleEntries) do
            checkNearbyVehicles()
            Wait(CHECK_INTERVAL)
        end
    end)
end)

RegisterNetEvent('qbx_core:client:removeVehZone', function(id)
    removeVehicleFromGrid(id)
end)