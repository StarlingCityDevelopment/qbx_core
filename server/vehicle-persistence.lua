local enable = GetConvar('qbx:enableVehiclePersistence', 'false') == 'true'
local full = GetConvar('qbx:vehiclePersistenceType', 'semi') == 'full'

local function enablePersistence(vehicle)
    Entity(vehicle).state:set('persisted', true, true)
end

exports('EnablePersistence', enablePersistence)

function DisablePersistence(vehicle)
    Entity(vehicle).state:set('persisted', nil, true)
end

exports('DisablePersistence', DisablePersistence)

if not enable then return end

assert(lib.checkDependency('qbx_vehicles', '1.4.1', true))

local SPAWN_TIMEOUT = 5000

---@param vehicle number
---@return number | nil
local function getVehicleId(vehicle)
    return Entity(vehicle).state.vehicleid or
        exports.qbx_vehicles:GetVehicleIdByPlate(qbx.getVehiclePlate(vehicle))
end

--- Spawn a vehicle with a timeout using a promise-style poll.
--- Returns netId and entity, or nil/nil on timeout.
---@param spawnData table
---@param timeout number
---@return number | nil, number | nil
local function spawnVehicleWithTimeout(spawnData, timeout)
    local netId, entity
    local done = false

    CreateThread(function()
        netId, entity = qbx.spawnVehicle(spawnData)
        done = true
    end)

    local deadline = GetGameTimer() + timeout
    while not done and GetGameTimer() < deadline do
        Wait(0)
    end

    if not done then
        print(('[qbx_core] spawnVehicleWithTimeout: timed out after %dms for model %s'):format(
            timeout, tostring(spawnData.model)))
        return nil, nil
    end

    return netId, entity
end

RegisterNetEvent('qbx_core:server:vehiclePropsChanged', function(netId, diff)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    local props = playerVehicle?.props
    if not props then return end

    if diff.bodyHealth then props.bodyHealth = GetVehicleBodyHealth(vehicle) end
    if diff.engineHealth then props.engineHealth = GetVehicleEngineHealth(vehicle) end
    if diff.tankHealth then props.tankHealth = GetVehiclePetrolTankHealth(vehicle) end
    if diff.dirtLevel then props.dirtLevel = GetVehicleDirtLevel(vehicle) end

    if diff.fuelLevel then
        props.fuelLevel = diff.fuelLevel ~= 'deleted' and diff.fuelLevel or nil
    end
    if diff.oilLevel then
        props.oilLevel = diff.oilLevel ~= 'deleted' and diff.oilLevel or nil
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

    exports.qbx_vehicles:SaveVehicle(vehicle, { props = props })
end)

local function getPedsInVehicleSeats(vehicle)
    local occupants = {}
    for i = -1, 7 do
        local ped = GetPedInVehicleSeat(vehicle, i)
        if ped ~= 0 then
            occupants[#occupants + 1] = { ped = ped, seat = i }
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
    if not playerVehicle then return end

    Entity(entity).state:set('persisted', nil, true)

    local success, veh = spawnVehicleWithTimeout({
        model = playerVehicle.props.model,
        spawnSource = vec4(coords.x, coords.y, coords.z, heading),
        bucket = bucket,
        props = playerVehicle.props,
    }, SPAWN_TIMEOUT)

    if not success or not veh then
        print(('[qbx_core] entityRemoved: failed to respawn vehicleId %d'):format(vehicleId))
        return
    end

    Entity(veh).state:set('sessionId', sessionId, true)
    Entity(veh).state:set('vehicleid', vehicleId, false)
    Entity(veh).state:set('persisted', true, true)

    for i = 1, #passengers do
        SetPedIntoVehicle(passengers[i].ped, veh, passengers[i].seat)
    end
end)

if not full then return end

local cachedVehicles = {}
local vehicleSpawnQueue = {}
local isProcessingQueue = false
local MAX_RETRIES = 5
local config = require 'config.server'

---@param id number
---@return boolean
local function isVehicleSpawned(id)
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        if Entity(vehicles[i]).state.vehicleid == id then
            return true
        end
    end
    return false
end

--- Persist a vehicle's current position and health to the database.
---@param vehicle number
---@param coords  vector3
---@param heading number
local function saveVehicle(vehicle, coords, heading)
    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    local props = playerVehicle?.props
    if not props then return end

    props.bodyHealth   = GetVehicleBodyHealth(vehicle)
    props.engineHealth = GetVehicleEngineHealth(vehicle)
    props.tankHealth   = GetVehiclePetrolTankHealth(vehicle)
    props.dirtLevel    = GetVehicleDirtLevel(vehicle)

    local vehType      = GetVehicleType(vehicle)
    if vehType == 'heli' or vehType == 'plane' then
        coords = vec3(coords.x, coords.y, coords.z + 1.0)
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        props = props,
        coords = vec4(coords.x, coords.y, coords.z, heading),
    })
end

--- Persist every active, marked vehicle.
local function saveAllVehicles()
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local v = vehicles[i]
        if DoesEntityExist(v) and Entity(v).state.persisted then
            saveVehicle(v, GetEntityCoords(v), GetEntityHeading(v))
        end
    end
end

--- Queue a vehicle spawn request.
--- The queue processor skips requests whose player has moved too far away and
--- retries them later, up to MAX_RETRIES times.
---@param src    number  player server id
---@param coords vector4
---@param id number
---@param model string
---@param props table
local function spawnVehicle(src, coords, id, model, props)
    if not src or not coords or not id or not model or not props then return end

    vehicleSpawnQueue[#vehicleSpawnQueue + 1] = {
        src     = src,
        coords  = coords,
        id      = id,
        model   = model,
        props   = props,
        retries = 0,
    }

    if isProcessingQueue then return end
    isProcessingQueue = true

    CreateThread(function()
        while #vehicleSpawnQueue > 0 do
            local request = table.remove(vehicleSpawnQueue, 1)

            if request.retries >= MAX_RETRIES then
                print(('[qbx_core] spawnVehicle: giving up on vehicleId %d after %d retries'):format(
                    request.id, MAX_RETRIES))
                cachedVehicles[request.id] = nil
                goto continue
            end

            if not isVehicleSpawned(request.id) then
                local ped       = GetPlayerPed(request.src)
                local pedCoords = GetEntityCoords(ped)
                local dist      = #(pedCoords - vec3(request.coords.x, request.coords.y, request.coords.z))

                if dist <= 75.0 then
                    local _, entity = spawnVehicleWithTimeout({
                        spawnSource = vec4(request.coords.x, request.coords.y, request.coords.z, request.coords.w),
                        model = request.model,
                        props = request.props,
                    }, SPAWN_TIMEOUT)

                    if entity and DoesEntityExist(entity) then
                        Entity(entity).state:set('vehicleid', request.id, false)
                        Entity(entity).state:set('onetimesave', request.props.plate, false)
                        Entity(entity).state:set('persisted', true, true)
                        config.setVehicleLock(entity, config.persistence.lockState)

                        TriggerClientEvent('qbx_core:client:removeVehZone', -1, request.id)
                        TriggerEvent('qbx_core:server:persistentVehicleSpawned', request.id)
                        cachedVehicles[request.id] = nil
                    else
                        request.retries += 1
                        vehicleSpawnQueue[#vehicleSpawnQueue + 1] = request
                    end
                else
                    request.retries += 1
                    vehicleSpawnQueue[#vehicleSpawnQueue + 1] = request
                end
            else
                cachedVehicles[request.id] = nil
            end

            ::continue::
            Wait(0)
        end

        isProcessingQueue = false
    end)
end

lib.callback.register('qbx_core:server:getVehiclesToSpawn', function()
    return cachedVehicles
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'qbx_vehicles' then return end

    local vehicles = exports.qbx_vehicles:GetPlayerVehicles({ states = 0 })
    if not vehicles then return end

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if vehicle.coords and vehicle.props and vehicle.props.plate
            and not isVehicleSpawned(vehicle.id)
        then
            cachedVehicles[vehicle.id] = vehicle.coords
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= cache.resource then return end
    saveAllVehicles()
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining ~= 60 then return end
    saveAllVehicles()
end)

RegisterNetEvent('qbx_core:server:spawnVehicle', function(id, coords)
    local src = source
    if not id or not coords then return end

    local cachedCoords = cachedVehicles[id]
    if not cachedCoords
        or cachedCoords.x ~= coords.x
        or cachedCoords.y ~= coords.y
        or cachedCoords.z ~= coords.z
        or cachedCoords.w ~= coords.w
    then
        return
    end

    local vehicle = exports.qbx_vehicles:GetPlayerVehicle(id)
    if not vehicle or not vehicle.modelName or not vehicle.props then return end

    spawnVehicle(src, coords, id, vehicle.modelName, vehicle.props)
end)

RegisterNetEvent('qbx_core:server:vehiclePositionChanged', function(netId)
    local src = source

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(vehicle)

    if #(pedCoords - vehicleCoords) > 10.0 then return end
    saveVehicle(vehicle, vehicleCoords, GetEntityHeading(vehicle))
end)

RegisterNetEvent('qbx_core:server:oneTimeSave', function(netId)
    local src = source

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(vehicle)

    if #(pedCoords - vehicleCoords) > 10.0 then return end

    DeleteVehicle(vehicle)

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not playerVehicle or not playerVehicle.props or not playerVehicle.coords then return end

    spawnVehicle(
        src,
        vec4(playerVehicle.coords.x, playerVehicle.coords.y,
            playerVehicle.coords.z, playerVehicle.coords.w),
        vehicleId,
        playerVehicle.modelName,
        playerVehicle.props
    )
end)