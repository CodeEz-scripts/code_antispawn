local entityEnumerator = {
    __gc = function(enum)
        if enum.destructor and enum.handle then
            enum.destructor(enum.handle)
        end
        enum.destructor = nil
        enum.handle = nil
    end
}

local function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(
        function()
            local iter, id = initFunc()
            if not id or id == 0 then
                disposeFunc(iter)
                return
            end

            local enum = {handle = iter, destructor = disposeFunc}
            setmetatable(enum, entityEnumerator)

            local next = true
            repeat
                coroutine.yield(id)
                next, id = moveFunc(iter)
            until not next

            enum.destructor, enum.handle = nil, nil
            disposeFunc(iter)
        end
    )
end

local function vehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

local function peds()
    return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end

local function objects()
    return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

Citizen.CreateThread(
    function()
        while true do
            Citizen.Wait(Config.checkInterval)  

            for veh in vehicles() do
                if Config.vehConfig.blacklist[GetEntityModel(veh)] then
                    local ped = GetPedInVehicleSeat(veh, -1)
                    if ped ~= 0 and IsPedAPlayer(ped) then
                        ClearPedTasksImmediately(ped)
                    end

                    while not NetworkHasControlOfEntity(veh) do
                        NetworkRequestControlOfEntity(veh)
                        Citizen.Wait(1)
                    end

                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                end
                Citizen.Wait(1)  
            end


            for ped in peds() do
                if Config.pedConfig.blacklist[GetEntityModel(ped)] and not IsPedAPlayer(ped) then
                    ClearPedTasksImmediately(ped)

                    while not NetworkHasControlOfEntity(ped) do
                        NetworkRequestControlOfEntity(ped)
                        Citizen.Wait(1)
                    end
                    
                    SetEntityAsMissionEntity(ped, true, true)
                    DeletePed(ped)
                end
                Citizen.Wait(1)  
            end


            local handle, object = FindFirstObject()
            local finished = false
            repeat
                Citizen.Wait(1)
                if Config.prop[GetEntityModel(object)] then
                    DeleteObjects(object)
                end
                finished, object = FindNextObject(handle)
            until not finished
            EndFindObject(handle)
        end
    end
)

function DeleteObjects(object)
    if DoesEntityExist(object) then
        NetworkRequestControlOfEntity(object)
        while not NetworkHasControlOfEntity(object) do
            Citizen.Wait(1)
        end
        DetachEntity(object, 0, false)
        SetEntityCollision(object, false, false)
        SetEntityAlpha(object, 0.0, true)
        SetEntityAsMissionEntity(object, true, true)
        SetEntityAsNoLongerNeeded(object)
        DeleteEntity(object)
    end
end
