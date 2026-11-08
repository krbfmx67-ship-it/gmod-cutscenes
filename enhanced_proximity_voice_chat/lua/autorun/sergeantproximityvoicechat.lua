
local voiceEnabled = CreateConVar("proximity_enabled", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Switches between global and proximity voice chat.", 0, 1)
local maxDist = CreateConVar("proximity_radius", 3000, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Radius, in which players can hear each other.")

local deadtalk = CreateConVar("proximity_alive_hears_dead", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Can alive players speak to the dead?", 0, 1)
local deadVC = CreateConVar("proximity_dead_voicechat", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Should dead players have their unique voice channel?", 0, 1)

local muteVolume = CreateConVar("proximity_mute", 0.3, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Volume of players/sounds, when they're behind the walls. (0-1)", 0, 1)

if SERVER then
	hook.Add( "PlayerCanHearPlayersVoice", "EPVC Maximum Voice Range", function(listener, talker)
		local proximityEnabled = voiceEnabled:GetInt()
		
		if proximityEnabled == 0 then
			return true, false
		end
		
		local canSpec = deadtalk:GetInt()
		local deadVoiceChat = deadVC:GetInt()
		local maxDistance = maxDist:GetInt()
		
		if  deadVoiceChat == 0 and (listener:Alive() and (not talker:Alive() or talker:Team() == TEAM_SPECTATOR)) then
			if canSpec == 0 then
				return false, false
			else
				return true, false
			end
		elseif deadVoiceChat == 1 and (not listener:Alive() or listener:Team() == TEAM_SPECTATOR) and (not talker:Alive() or talker:Team() == TEAM_SPECTATOR) then
			return true, false
		end

		
		local ply = listener
		local observerTarget = listener:GetObserverTarget()
		if IsValid(observerTarget) then ply = observerTarget end
		
		local distance = ply:GetPos():Distance(talker:GetPos())

		if distance > maxDistance then
			return false, false
		end

		return true, true
	end)
else
	local function UpdateVoiceDSP(listener, talker)
		if not IsValid(listener) or not IsValid(talker) or listener == talker then return end

		if not voiceEnabled:GetBool() then
			talker:SetVoiceVolumeScale(1)
			return
		end
		
		if deadVC:GetBool() and not listener:Alive() or listener:Team() == TEAM_SPECTATOR then
			if not talker:Alive() or talker:Team() == TEAM_SPECTATOR then
				talker:SetVoiceVolumeScale(1)
				return
			end
		end

		local ply = listener
		local observerTarget = listener:GetObserverTarget()
		if IsValid(observerTarget) then ply = observerTarget end

		local distance = ply:GetPos():Distance(talker:GetPos())

		if distance > maxDist:GetInt() then return end

		local trace = util.TraceLine({
			start = ply:EyePos(),
			endpos = talker:EyePos(),
			filter = function(ent)
				return ent ~= ply and ent ~= talker and not ent:IsPlayer() and not ent:IsNPC() and ent:GetClass() ~= "prop_physics"
			end
		})

		local volume = 1
		local mute = muteVolume:GetFloat()

		if distance < 200 then
			mute = math.min(muteVolume:GetFloat() * 2, 1)
		end

		if talker:WaterLevel() == 3 then
			mute = math.max(muteVolume:GetFloat() / 2, 0)
		end

		if (trace.Hit and (trace.MatType or 0) ~= 71) or talker:WaterLevel() == 3 then
			volume = (((distance / maxDist:GetInt()) * -1) + 1) * mute
		else
			volume = (((distance / maxDist:GetInt()) * -1) + 1)
		end

		talker:SetVoiceVolumeScale(volume)
	end
	
	timer.Create("Update EPVC", 0.25, 0, function()
		local listener = LocalPlayer()

		if !IsValid(listener) then return end
	
		for _, talker in player.Iterator() do
			if IsValid(talker) and not talker:IsMuted() then
				UpdateVoiceDSP(listener, talker)
			end
		end
	end)

	hook.Add("PlayerStartVoice", "EPVC ClientVoiceFilterStart", function(talker)
		local listener = LocalPlayer()
		if not IsValid(listener) then return end
		
		if talker:IsMuted() then return end

		UpdateVoiceDSP(listener, talker)
	end)

	hook.Add("PlayerEndVoice", "EPVC ClientVoiceFilterEnd", function(ply)
		if IsValid(ply) then
			ply:SetVoiceVolumeScale(1)
		end
	end)
end