local call = remote.call

---@return LuaForce?
local function GetClaimedLand(entity)
    local entity_prototypes = game.entity_prototypes
    for _, poleName in pairs(POLES) do
        local prototype = entity_prototypes[poleName]
        local radius = prototype.supply_area_distance
        if entity.type == "electric-pole" then
            radius = radius + entity.prototype.supply_area_distance
        end
        local claimPoles = entity.surface.find_entities_filtered{
            area = Area(entity.position, radius),
            name = poleName
        }
        for _, pole in pairs(claimPoles) do
            if pole.force ~= entity.force then
                return pole.force
            end
        end
        if #claimPoles > 0 then
            return claimPoles[1].force
        end
    end
end

local function GetClaimCost(entity)
    local supply_area = entity.prototype.supply_area_distance
    local cost = supply_area * supply_area * land_claim_cost
    return cost
end

local function GetClaimTransferableCost(entity)
    if entity.type == "electric-pole" then
        local supply_area = entity.prototype.supply_area_distance
        local cost = supply_area * supply_area * land_claim_cost
        return cost, CanTransferCredits(entity, cost)
    end
    return false
end

function ClaimPoleBuilt(entity)
    local cost = GetClaimCost(entity)
    if cost then
        call("EasyAPI", "deposit_force_money", entity.force, -cost)
    end
end

function ClaimPoleRemoved(entity)
    local cost = GetClaimCost(entity)
    if cost then
        AddCredits(entity.force, cost)
    end
end

function DestroyInvalidEntities(entity, player)
    local instigatingForce = entity.force
    if instigatingForce then
        -- Check if land is claimed.
        local claimedLand = GetClaimedLand(entity)
        local cost, is_affordable = GetClaimTransferableCost(entity)
        local noBuildDueToEnemyLand = (
            claimedLand and claimedLand ~= instigatingForce
            and not claimedLand.get_friend(instigatingForce)
            and not PLACE_ENEMY_TERRITORY_ITEMS[entity.name]
        )
        local noBuildDueToNoMansLand = (claimedLand == nil and not PLACE_NOMANSLAND_ITEMS[entity.name])
        local noBuildDueToExpense = (cost and not is_affordable)
        if player then
            if noBuildDueToExpense then
                player.print{"message.cannot-claim"}
            end
            if noBuildDueToEnemyLand then
                player.print{"message.no-build-opponent-land"}
            end
            if noBuildDueToNoMansLand then
                player.print{"message.no-mans-land-restriction"}
            end
        end
        -- Don't allow build if invalid build spot.
        if noBuildDueToEnemyLand or noBuildDueToNoMansLand or noBuildDueToExpense then
            if player then
                player.mine_entity(entity, true)
            else
                entity.destroy()
            end
            return false
        end
        return true
    end
end
