local enable = GetConvar('qbx:enableVehiclePersistence', 'false') == 'true'
local full = GetConvar('qbx:vehiclePersistenceType', 'semi') == 'full'

---@param vehicle number
local function enablePersistence(vehicle)
    Entity(vehicle).state:set('persisted', true, true)
end

exports('EnablePersistence', enablePersistence)

---@param vehicle number
function DisablePersistence(vehicle)
    Entity(vehicle).state:set('persisted', nil, true)
end

exports('DisablePersistence', DisablePersistence)

if not enable then return end

assert(lib.checkDependency('qbx_vehicles', '1.4.1', true))

local function getVehicleId(vehicle)
    return Entity(vehicle).state.vehicleid or
    exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
end

RegisterNetEvent('qbx_core:server:vehiclePropsChanged', function(netId, diff)
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local props = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)?.props
    if not props then return end

    if diff.bodyHealth then
        props.bodyHealth = GetVehicleBodyHealth(vehicle)
    end

    if diff.engineHealth then
        props.engineHealth = GetVehicleEngineHealth(vehicle)
    end

    if diff.tankHealth then
        props.tankHealth = GetVehiclePetrolTankHealth(vehicle)
    end

    if diff.fuelLevel then
        props.fuelLevel = diff.fuelLevel ~= 'deleted' and diff.fuelLevel or nil
    end

    if diff.oilLevel then
        props.oilLevel = diff.oilLevel ~= 'deleted' and diff.oilLevel or nil
    end

    if diff.dirtLevel then
        props.dirtLevel = GetVehicleDirtLevel(vehicle)
    end

    if diff.windows then
        props.windows = diff.windows ~= 'deleted' and diff.windows or nil
    end

    if diff.doors then
        props.doors = diff.doors ~= 'deleted' and diff.doors or nil
    end

    if diff.tyres then
        props.tyres = diff.tyres ~= 'deleted' and diff.tyres or nil
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        props = props,
    })
end)

local function getPedsInVehicleSeats(vehicle)
    local occupants = {}
    local occupantsI = 1
    for i = -1, 7 do
        local ped = GetPedInVehicleSeat(vehicle, i)
        if ped ~= 0 then
            occupants[occupantsI] = {
                ped = ped,
                seat = i,
            }
            occupantsI += 1
        end
    end
    return occupants
end

AddEventHandler('entityRemoved', function(entity)
    if not Entity(entity).state.persisted then return end
    local sessionId = Entity(entity).state.sessionId
    local coords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    local bucket = GetEntityRoutingBucket(entity)
    local passengers = getPedsInVehicleSeats(entity)

    local vehicleId = getVehicleId(entity)
    if not vehicleId then return end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not playerVehicle or not playerVehicle.props then return end

    if DoesEntityExist(entity) then
        Entity(entity).state:set('persisted', nil, true)
        DeleteVehicle(entity)
    end

    SetTimeout(100, function()
        local success, veh = pcall(function()
            return qbx.spawnVehicle({
                model = playerVehicle.props.model,
                spawnSource = vec4(coords.x, coords.y, coords.z, heading),
                bucket = bucket,
                props = playerVehicle.props
            })
        end)

        if not success or not veh then
            lib.print.warn(('Failed to respawn persisted vehicle %s'):format(vehicleId))
            return
        end

        local _, vehicle = success, veh
        if type(veh) == 'table' then
            vehicle = veh[2] or veh
        elseif type(success) == 'number' then
            vehicle = success
        end

        if not DoesEntityExist(vehicle) then
            lib.print.warn(('Respawned vehicle %s does not exist'):format(vehicleId))
            return
        end

        Entity(vehicle).state:set('sessionId', sessionId, true)
        Entity(vehicle).state:set('vehicleid', vehicleId, false)
        Entity(vehicle).state:set('persisted', true, true)

        for i = 1, #passengers do
            local passenger = passengers[i]
            if DoesEntityExist(passenger.ped) then
                SetPedIntoVehicle(passenger.ped, vehicle, passenger.seat)
            end
        end
    end)
end)

if not full then return end

local SPAWN_DELAY = 100
local MAX_SPAWN_RETRIES = 3
local cachedVehicles = {}
local vehicleSpawnQueue = {}
local spawnedVehicleIds = {}
local isProcessingQueue = false
local config = require 'config.server'

---@param id number
---@return boolean
local function isVehicleSpawned(id)
    if spawnedVehicleIds[id] then
        local vehicles = GetGamePool('CVehicle')
        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            if Entity(vehicle).state.vehicleid == id then
                return true
            end
        end

        spawnedVehicleIds[id] = nil
    end

    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if Entity(vehicle).state.vehicleid == id then
            spawnedVehicleIds[id] = true
            return true
        end
    end

    return false
end

--- Save the vehicle position to the database
---@param vehicle number
---@param coords vector3
---@param heading number
local function saveVehicle(vehicle, coords, heading)
    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local props = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)?.props
    if not props then return end

    local type = GetVehicleType(vehicle)

    props.bodyHealth = GetVehicleBodyHealth(vehicle)
    props.engineHealth = GetVehicleEngineHealth(vehicle)
    props.tankHealth = GetVehiclePetrolTankHealth(vehicle)
    props.dirtLevel = GetVehicleDirtLevel(vehicle)

    if type == 'heli' or type == 'plane' then
        coords = vec3(coords.x, coords.y, coords.z + 1.0)
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        props = props,
        coords = vec4(coords.x, coords.y, coords.z, heading)
    })
end

--- Save all vehicle positions to the database
local function saveAllVehicle()
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if DoesEntityExist(vehicle) and Entity(vehicle).state.persisted then
            saveVehicle(vehicle, GetEntityCoords(vehicle), GetEntityHeading(vehicle))
        end
    end
end

---@param request table
---@param retryCount number?
---@return boolean success
local function trySpawnVehicle(request, retryCount)
    retryCount = retryCount or 0

    if isVehicleSpawned(request.id) then
        lib.print.debug(('Vehicle %s already spawned, skipping'):format(request.id))
        return true
    end

    local success, result = pcall(function()
        return qbx.spawnVehicle({
            spawnSource = vec4(request.coords.x, request.coords.y, request.coords.z, request.coords.w),
            model = request.model,
            props = request.props
        })
    end)

    if not success then
        lib.print.warn(('Failed to spawn vehicle %s: %s'):format(request.id, tostring(result)))
        if retryCount < MAX_SPAWN_RETRIES then
            Wait(SPAWN_DELAY * (retryCount + 1))
            return trySpawnVehicle(request, retryCount + 1)
        end
        return false
    end

    local veh = result
    if type(result) == 'table' then
        veh = result[2] or result
    end

    if not veh or not DoesEntityExist(veh) then
        lib.print.warn(('Vehicle %s spawn returned invalid entity'):format(request.id))
        if retryCount < MAX_SPAWN_RETRIES then
            Wait(SPAWN_DELAY * (retryCount + 1))
            return trySpawnVehicle(request, retryCount + 1)
        end
        return false
    end

    TriggerClientEvent('qbx_core:client:removeVehZone', -1, request.id)
    cachedVehicles[request.id] = nil
    spawnedVehicleIds[request.id] = true
    Entity(veh).state:set('vehicleid', request.id, false)
    Entity(veh).state:set('persisted', true, true)
    config.setVehicleLock(veh, config.persistence.lockState)

    lib.print.debug(('Successfully spawned vehicle %s'):format(request.id))
    return true
end

---@param coords vector4
---@param id number
---@param model string
---@param props table
local function spawnVehicle(coords, id, model, props)
    if not coords or not id or not model or not props then
        lib.print.warn('spawnVehicle called with invalid parameters')
        return
    end

    for i = 1, #vehicleSpawnQueue do
        if vehicleSpawnQueue[i].id == id then
            lib.print.debug(('Vehicle %s already in spawn queue'):format(id))
            return
        end
    end

    if isVehicleSpawned(id) then
        lib.print.debug(('Vehicle %s already spawned'):format(id))
        cachedVehicles[id] = nil
        TriggerClientEvent('qbx_core:client:removeVehZone', -1, id)
        return
    end

    vehicleSpawnQueue[#vehicleSpawnQueue + 1] = {
        coords = coords,
        id = id,
        model = model,
        props = props,
        addedAt = GetGameTimer()
    }

    if not isProcessingQueue then
        isProcessingQueue = true

        CreateThread(function()
            while #vehicleSpawnQueue > 0 do
                local request = table.remove(vehicleSpawnQueue, 1)

                if GetGameTimer() - request.addedAt < 30000 then
                    trySpawnVehicle(request)
                else
                    lib.print.debug(('Skipping stale spawn request for vehicle %s'):format(request.id))
                end

                Wait(SPAWN_DELAY)
            end

            isProcessingQueue = false
        end)
    end
end

lib.callback.register('qbx_core:server:getVehiclesToSpawn', function()
    for id in pairs(cachedVehicles) do
        if isVehicleSpawned(id) then
            cachedVehicles[id] = nil
        end
    end
    return cachedVehicles
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'qbx_vehicles' then return end

    cachedVehicles = {}
    spawnedVehicleIds = {}

    SetTimeout(1000, function()
        local vehicles = exports.qbx_vehicles:GetPlayerVehicles({ states = 0 })
        if not vehicles then return end

        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            if vehicle.coords and vehicle.props and vehicle.props.plate and not isVehicleSpawned(vehicle.id) then
                cachedVehicles[vehicle.id] = vehicle.coords
            end
        end

        lib.print.info(('Loaded %d vehicles for persistence'):format(table.count and table.count(cachedVehicles) or 0))
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= cache.resource then return end

    saveAllVehicle()
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining ~= 60 then return end

    saveAllVehicle()
end)

RegisterNetEvent('qbx_core:server:spawnVehicle', function(id, coords)
    local src = source
    if not id or not coords then return end

    local playerState = Player(src).state
    local lastSpawnRequest = playerState.lastVehicleSpawnRequest or 0
    if GetGameTimer() - lastSpawnRequest < 500 then
        return
    end
    playerState.lastVehicleSpawnRequest = GetGameTimer()

    local cachedCoords = cachedVehicles[id]
    if not cachedCoords then
        return
    end

    local tolerance = 0.5
    if math.abs(cachedCoords.x - coords.x) > tolerance or
        math.abs(cachedCoords.y - coords.y) > tolerance or
        math.abs(cachedCoords.z - coords.z) > tolerance then
        return
    end

    local vehicle = exports.qbx_vehicles:GetPlayerVehicle(id)
    if not vehicle or not vehicle.modelName or not vehicle.props then return end

    spawnVehicle(coords, id, vehicle.modelName, vehicle.props)
end)

CreateThread(function()
    while true do
        Wait(60000)

        local activeIds = {}
        local vehicles = GetGamePool('CVehicle')

        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            local id = Entity(vehicle).state.vehicleid
            if id then
                activeIds[id] = true
            end
        end

        for id in pairs(spawnedVehicleIds) do
            if not activeIds[id] then
                spawnedVehicleIds[id] = nil
            end
        end
    end
end)