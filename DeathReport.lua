
--[[----------------------------------------------------------
	DeathReport
	----------------------------------------------------------
	Report information about the cause of death to a the
	group chat
  ]]--

--[[----------------------------------------------------------
	INITIALIZATION
  ]]----------------------------------------------------------
DER 					= {}
DER.name				= "DeathReport"
DER.command				= "/der"
DER.version				= 0.01
DER.language			= "English"
DER.Gather 				= {}
DER.Gather.Data   		= {}

-- Default Saved Variables
FTC.defaults			= {
	["Output"] 			        = "/group",
	
}

--===================================================================
-- given a numeric value formats output with comma to separate thousands
-- and rounded to given decimal places
--
--
local function format_num(amount, decimal, prefix, neg_prefix)
  local str_amount,  formatted, famount, remain

  decimal = decimal or 2  -- default 2 decimal places
  neg_prefix = neg_prefix or "-" -- default negative sign

  famount = math.abs(round(amount,decimal))
  famount = math.floor(famount)

  remain = round(math.abs(amount) - famount, decimal)

        -- comma to separate the thousands
  formatted = comma_value(famount)

        -- attach the decimal portion
  if (decimal > 0) then
    remain = string.sub(tostring(remain),3)
    formatted = formatted .. "." .. remain ..
                string.rep("0", decimal - string.len(remain))
  end

        -- attach prefix string e.g '$' 
  formatted = (prefix or "") .. formatted 

        -- if value is negative then format accordingly
  if (amount<0) then
    if (neg_prefix=="()") then
      formatted = "("..formatted ..")"
    else
      formatted = neg_prefix .. formatted 
    end
  end

  return formatted
end
	
--[[ 
 * Initialization function
 * Runs once, when the add-on is fully loaded
 ]]-- 
function DER.Initialize( eventCode, addOnName )

	-- Only set up for FTC
	if ( addOnName ~= DER.name ) 	then return end
	
	-- Load saved variables
	DER.vars = ZO_SavedVars:New( 'DER_VARS' , math.floor( DER.version * 100 ) , nil , DER.defaults )
	
	-- Register the slash command handler
	SLASH_COMMANDS[DER.command] = DER.Slash

	-- Register keybinding
	ZO_CreateStringId("SI_BINDING_NAME_DEATH_REPORT_POST", "Post Death Report")
end

-- Hook initialization onto the EVENT_ADD_ON_LOADED listener
EVENT_MANAGER:RegisterForEvent( "DER" , EVENT_ADD_ON_LOADED , DER.Initialize )

DER.Reporting.OutputFormat = "(%s) - %s: %s (%s/%s)"
function DER.Reporting:Post()
	local format = DER.Reporting.OutputFormat
	 -- - Added DeathRecap API:
  --       * GetNumKillingAttacks
  --       * GetKillingAttackInfo
  --       * DoesKillingAttackHaveAttacker
  --       * GetKillingAttackerInfo
  --       * GetNumDeathRecapHints
  --       * GetDeathRecapHintInfo
  -- http://pastebin.com/urfAS473
  if(DER.Gather.Data)
  	local output = "Death: "
  	local firstTime = nil;
  	for k, v in pairs(DER.Gather.Data) do
  		if(not firstTime) then
  			firstTime = k
  			local prefix = (v.heal) and "+" or "-"
  			local hpPercentage = v.hp / v.effectMaxHp * 100
  			local hpDiff = v.hp - v.effectMaxHp;
  			output = output .. string.format(format, format_num(0, 2), 
  				v.ability, format_num(v.value, 2, prefix), 
  				format_num(hpDiff, 0), format_num(hpPercentage, 2, "%"))
  		end
  	end
  	-- Determine appropriate channel
	local channel = IsUnitGrouped('player') and "/p " or "/say "

	-- Print output to chat
	CHAT_SYSTEM.textEntry:SetText( channel .. output )
  else
  	d("No data available!")
  end
  
end



function DER:RegisterEvents()
	-- Combat Events
	EVENT_MANAGER:RegisterForEvent( "DER" , EVENT_COMBAT_EVENT 					, DER.OnCombatEvent )
end

--[[----------------------------------------------------------
	EVENT HANDLERS
 ]]-----------------------------------------------------------
 
--[[ 
 * Runs on the EVENT_COMBAT_EVENT listener.
 * This handler fires every time a combat effect is registered on a valid unitTag
 ]]--
local function truncateTable(table, maxEntries)
  local count = 0
  for k, v in pairs(T) do 
  	count = count + 1 
  	if(count > maxEntries)
  		table[k] = nil
  	end
  end
  return count
end
function DER.OnCombatEvent( eventCode , result , isError , abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log )
	-- Retrieve the data
	local damage	= newDamage.dam
	local name		= newDamage.name
	local target	= newDamage.target

	-- Determine the context
	local context 	= ( sourceType == 0 ) and "In" or "Out"

	-- Modify the name
	abilityName = string.gsub ( abilityName , ' %(.*%)' , "" )

	-- Incoming events
	elseif ( context == "In") then
		local currentHp, maxHp, effectMaxHp = GetUnitPower("player", POWERTYPE_HEALTH)
		local entry = {
			["hp"]  		= currentHp
			["maxhp"]   	= maxHp
			["effectMaxHp"] = effectMaxHp
			["target"]		= targetName,
			["ability"]		= abilityName,
			["result"]		= result,
			["value"]		= hitValue,
			["power"]		= powerType,
			["type"]		= damageType,
			["ms"]			= GetGameTimeMilliseconds(),
			["crit"]		= ( result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_DOT_TICK_CRITICAL or result == ACTION_RESULT_HOT_TICK_CRITICAL ) and true or false,
			["heal"]		= ( result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL ) and true or false,
		}
		table.insert(DER.Gather.Data, entry, entry.ms)
		table.sort( DER.Gather.Data , function(x,y) return x.ms > y.total end )
		truncateTable(DER.Gather.Data, 15)
	end
end

 --[[ 
 * The slash command handler
 ]]-- 
function DER.Slash( text )

	-- Display the current version
	d( "You are using DeathReport version "  DER.version .. "." )
end


