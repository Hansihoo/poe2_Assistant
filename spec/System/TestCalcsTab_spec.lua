describe("CalcsTab Node Power cache", function()
	local function makeNode(nodeId, allocated, score)
		return {
			id = nodeId, modKey = "shared stat text", type = "Normal", allocMode = 0,
			alloc = allocated, power = {}, pathDist = 1, score = score,
		}
	end

	-- Run the real PowerBuilder with a deterministic calculator. Scores model distinct
	-- calculation results; the calculator must be called for each distinct context.
	local function scoreNodes(nodes, radiusJewels, combined, clusterNodes)
		local calls = 0
		local tab = setmetatable({
			build = { spec = { nodes = nodes, tree = { clusterNodeMap = clusterNodes or {} } } },
			mainEnv = { grantedPassives = {}, radiusJewelList = radiusJewels or {} },
			powerStat = not combined and { stat = "CombinedDPS" } or nil,
		}, { __index = common.classes.CalcsTab })
		local baseline = {
			CombinedDPS = 100, Life = 3000, LifeUnreserved = 3000, Armour = 0,
			EnergyShield = 0, Evasion = 0, LifeRegenRecovery = 0, EnergyShieldRegenRecovery = 0,
		}
		tab.miscCalculator = { function(request)
			calls = calls + 1
			local node = next(request.addNodes or request.removeNodes)
			local delta = request.addNodes and node.score or -node.score
			local output = copyTable(baseline)
			output.CombinedDPS = baseline.CombinedDPS + delta
			output.LifeUnreserved = baseline.LifeUnreserved + delta
			return output
		end, baseline }
		tab:PowerBuilder()
		return calls
	end

	local contexts = {
		{ name = "inside versus outside a radius jewel", jewels = { { nodes = { [1] = true } } } },
		{ name = "different radius jewels", jewels = { { nodes = { [1] = true } }, { nodes = { [2] = true } } } },
		{ name = "overlapping radius jewels", jewels = { { nodes = { [1] = true, [2] = true } }, { nodes = { [2] = true } } } },
		{ name = "small versus notable scaling", change = { type = "Notable" } },
		{ name = "attribute versus non-attribute scaling", change = { isAttribute = true } },
		{ name = "weapon set conditions", change = { allocMode = 1 } },
		{ name = "different weapon sets", firstMode = 1, change = { allocMode = 2 } },
	}
	for _, context in ipairs(contexts) do
		for _, allocated in ipairs({ false, true }) do
			it("isolates " .. (allocated and "remove" or "add") .. " scores for " .. context.name, function()
				for _, reverse in ipairs({ false, true }) do
					local first = makeNode(1, allocated, 10)
					local second = makeNode(2, allocated, 30)
					first.allocMode = context.firstMode or 0
					for field, value in pairs(context.change or {}) do
						second[field] = value
					end
					-- Separate distance buckets force both possible cache-fill orders.
					first.pathDist = reverse and 2 or 1
					second.pathDist = reverse and 1 or 2
					first.depends, second.depends = { first }, { second }
					local calls = scoreNodes({ first, second }, context.jewels)
					local sign = allocated and -1 or 1
					assert.are.equal(2, calls)
					assert.are.equal(sign * 10, first.power.singleStat)
					assert.are.equal(sign * 30, second.power.singleStat)
					if allocated then
						assert.are.equal(sign * 10, first.power.pathPower)
						assert.are.equal(sign * 30, second.power.pathPower)
					end
				end
			end)
		end
	end

	it("isolates single-node add pathPower scores", function()
		local inside = makeNode(1, false, 10)
		local outside = makeNode(2, false, 30)
		inside.path, outside.path = { inside }, { outside }
		assert.are.equal(2, scoreNodes({ inside, outside }, { { nodes = { [1] = true } } }))
		assert.are.equal(10, inside.power.pathPower)
		assert.are.equal(30, outside.power.pathPower)
	end)

	it("isolates combined offence and defence scores", function()
		local inside = makeNode(1, false, 10)
		local outside = makeNode(2, false, 30)
		assert.are.equal(2, scoreNodes({ inside, outside }, { { nodes = { [1] = true } } }, true))
		assert.are.equal(0.1, inside.power.offence)
		assert.are.equal(0.3, outside.power.offence)
		assert.are.equal(10 / 3000, inside.power.defence)
		assert.are.equal(30 / 3000, outside.power.defence)
	end)

	it("shares equivalent contexts while keeping add and remove separate", function()
		local added = makeNode(1, false, 10)
		local equivalent = makeNode(2, false, 10)
		local removed = makeNode(3, true, 10)
		local equivalentRemoved = makeNode(4, true, 10)
		equivalent.allocMode = nil -- Missing mode is equivalent to mode zero.
		assert.are.equal(2, scoreNodes({ added, equivalent, removed, equivalentRemoved }))
		assert.are.equal(10, added.power.singleStat)
		assert.are.equal(10, equivalent.power.singleStat)
		assert.are.equal(-10, removed.power.singleStat)
		assert.are.equal(-10, equivalentRemoved.power.singleStat)
	end)

	it("uses context keys for cluster nodes sharing the regular-node cache", function()
		local regular = makeNode(1, false, 10)
		local cluster = makeNode(2, false, 30)
		cluster.type = "Notable"
		local equivalentCluster = makeNode(3, false, 30)
		equivalentCluster.type = "Notable"
		assert.are.equal(2, scoreNodes({ regular }, nil, false, { cluster, equivalentCluster }))
		assert.are.equal(10, regular.power.singleStat)
		assert.are.equal(30, cluster.power.singleStat)
		assert.are.equal(30, equivalentCluster.power.singleStat)
	end)
end)
