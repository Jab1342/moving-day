--!nonstrict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Payout = require(Shared.Logic.Payout)
local Benefits = require(Shared.Logic.PassBenefits)
local PayoutService = {}
PayoutService.__index = PayoutService
function PayoutService.new(data, remotes)
	return setmetatable({ data = data, remotes = remotes }, PayoutService)
end
function PayoutService:Award(job)
	if not job.report then
		local recipients = {}
		local passes = {}
		for _, player in job.crew.members do
			if player.Parent == Players and self.data:Get(player) then
				if self.passesForPlayer then
					local owned = self.passesForPlayer(player)
					if not owned then
						return nil, "EntitlementsPending"
					end
					passes[tostring(player.UserId)] = owned
				end
				table.insert(recipients, player.UserId)
			end
		end
		if #recipients == 0 then
			return nil, "NoRecipients"
		end
		local lines = {}
		for _, uid in job.order do
			local item = job.snapshots[uid]
			local kept = if item.state == "Delivered"
				then math.floor(item.def.value * item.hp / Config.ItemMaxHP)
				else 0
			table.insert(lines, {
				itemUid = uid,
				itemId = item.def.id,
				valueKept = kept,
				valueLost = item.def.value - kept,
				blameUserId = item.blame,
			})
		end
		job.report = Payout.compute({
			jobId = job.id,
			tier = job.tier,
			elapsedSeconds = (job.completedAt or workspace:GetServerTimeNow()) - job.startedAt,
			assist = job.assist,
			lines = lines,
			memberUserIds = recipients,
			nextJob = { tier = job.tier, lotId = job.crew.padId },
		}, #recipients)
		if self.passesForPlayer then
			job.report = Benefits.apply(job.report, recipients, passes, job.assist)
		end
		-- Ownership checks may take time; still leave the full payout display window.
		job.returnAt =
			math.max(job.returnAt or 0, workspace:GetServerTimeNow() + Config.PayoutDisplaySeconds)
		job.awarded = {}
	end
	for _, player in job.crew.members do
		local share = job.report.shares[tostring(player.UserId)]
		if share and not job.awarded[player.UserId] and self.data:Get(player) then
			local ok = self.data:Update(player, function(profile)
				profile.cash += share
				profile.xp += job.report.xpEach
				profile.stats.jobs += 1
				profile.firstJobDone = true
				for _, line in job.report.lines do
					local item = job.snapshots[line.itemUid]
					if item.state == "Delivered" then
						profile.stats.delivered += 1
						if item.hp == Config.ItemMaxHP then
							profile.catalog[item.def.id] = true
						end
					elseif item.state == "Broken" then
						profile.stats.broken += 1
					end
					profile.stats.moneyLost += line.valueLost
				end
			end)
			if ok then
				job.awarded[player.UserId] = true
				if self.analytics then
					self.analytics:Funnel(player, 6)
					self.analytics:Economy(player, share, self.data:Get(player).cash, "JobPayout")
					self.analytics:Custom(
						player,
						"JobCompleted",
						workspace:GetServerTimeNow() - job.startedAt,
						{
							[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = job.tier,
							[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = tostring(
								job.report.stars
							),
							[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = tostring(
								#job.crew.members
							),
						}
					)
				end
				self.remotes.Job.Payout:FireClient(player, job.report)
			end
		end
	end
	return job.report
end
return PayoutService
