
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
DER.Reporting     = {}

-- Default Saved Variables
FTC.defaults			= {
	["Output"] 			        = "/group",
	
}
-- from sam_lie
-- Compatible with Lua 5.0 and 5.1.
-- Disclaimer : use at own risk especially for hedge fund reports :-)

---============================================================
-- add comma to separate thousands
-- 
function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

---============================================================
-- rounds a number to the nearest decimal places
--
function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

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

function DER.Filter( result , abilityName , sourceType , sourceName , targetName , hitValue )

  -- Debugging
  -- d( sourceName .. "/" .. sourceType .. "/" .. abilityName .. "/" .. targetName .. "/" .. result .. "/" ..  hitValue )
  
  -- Ignore by default
  local isValid = false
  
  -- Ignore miscellaneous player damage
  if ( sourceType == COMBAT_UNIT_TYPE_OTHER ) then isValid = false
  
  -- Outgoing player actions
  elseif ( sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET ) then
  
    -- Reflag self-harm
    if ( string.match( targetName , FTC.Player.nicename ) and ( result ~= ACTION_RESULT_HEAL and result ~= ACTION_RESULT_HOT_TICK and result ~= ACTION_RESULT_HOT_TICK_CRITICAL ) ) then sourceType = COMBAT_UNIT_TYPE_NONE end
  
    -- Immunities
    if ( result == ACTION_RESULT_IMMUNE or result == ACTION_RESULT_DODGED or result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_MISS ) then isValid = true
    
    -- Ignore zeroes
    elseif ( hitValue == 0 ) then isValid = false
    
    -- Damage
    elseif ( result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL ) then isValid = true
    
    -- Healing
    elseif ( result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL ) then isValid = true end
  
  
  -- Incoming actions
  elseif ( sourceType == COMBAT_UNIT_TYPE_NONE and string.match( targetName , FTC.Player.nicename ) ) then 
  
    -- Immunities
    if ( result == ACTION_RESULT_IMMUNE or result == ACTION_RESULT_DODGED or result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_MISS ) then isValid = true
    
    -- Ignore zeroes
    elseif ( hitValue == 0 ) then isValid = false
      
    -- Damage
    elseif ( result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL ) then isValid = true
      
    -- Falling damage
    elseif ( result == ACTION_RESULT_FALL_DAMAGE ) then isValid = true
    
    -- Healing
    elseif ( result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL ) then isValid = true end

  -- Group actions
  elseif ( sourceType == COMBAT_UNIT_TYPE_GROUP ) then
  
    -- Damage
    if ( result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL ) then isValid = true end 
  end
  
  -- Return results
  return isValid, result , abilityName , sourceType , sourceName , targetName , hitValue
end
	
--[[ 
 * Initialization function
 * Runs once, when the add-on is fully loaded
 ]]-- 
function DER.Initialize( eventCode, addOnName )

	if ( addOnName ~= DER.name ) 	then return end
	
	-- Load saved variables
	DER.vars = ZO_SavedVars:New( 'DER_VARS' , math.floor( DER.version * 100 ) , nil , DER.defaults )
	
	-- Register the slash command handler
	SLASH_COMMANDS[DER.command] = DER.Slash

  DER:RegisterEvents()

	-- Register keybinding
	ZO_CreateStringId("SI_BINDING_NAME_DEATH_REPORT_POST", "Post Death Report")
end

-- Hook initialization onto the EVENT_ADD_ON_LOADED listener
EVENT_MANAGER:RegisterForEvent( "DER" , EVENT_ADD_ON_LOADED , DER.Initialize )

DER.Reporting.OutputFormat = "%ss: %s (%s/%s)"
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
  if(DER.Gather.Data) then
  	local output = "Events: "
  	local firstTime = nil;
  	for k, v in pairs(DER.Gather.Data) do
  		if(not firstTime) then
  			firstTime = v.ms
      end
      local prefix = (v.heal) and "+" or "-"
      local hpPercentage = v.hp / v.effectMaxHp * 100
      local hpDiff = v.hp - v.effectMaxHp;
      output = output .. string.format(format, format_num((v.ms - firstTime)/1000, 1), 
          format_num(v.value, 1, prefix), 
          format_num(hpDiff, 0), format_num(hpPercentage, 1) .. "%") .. " || "
  	end
  	-- Determine appropriate channel
	local channel = IsUnitGrouped('player') and "/p " or "/say "

	-- Print output to chat
	CHAT_SYSTEM.textEntry:SetText( channel .. output )
  else
  	d("No data available!")
  end
  
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
  for k, v in pairs(table) do 
  	count = count + 1 
  	if(count > maxEntries) then
  		table[k] = nil
  	end
  end
  return count
end
function DER.OnCombatEvent( eventCode , result , isError , abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log )
	-- Verify it's a valid result type
  isValid, result , abilityName , sourceType , sourceName , targetName , hitValue = FTC.Damage:Filter( result , abilityName , sourceType , sourceName , targetName , hitValue )
  if not isValid then return end

  -- Determine the context
	local context 	= ( sourceType == 0 ) and "In" or "Out"

	-- Modify the name
	abilityName = string.gsub ( abilityName , ' %(.*%)' , "" )

	-- Incoming events
	if ( context == "In") and math.abs(hitValue) > 50 then
		local currentHp, maxHp, effectMaxHp = GetUnitPower("player", POWERTYPE_HEALTH)
		local entry = {
			["hp"]  		    = currentHp,
			["maxhp"]   	  = maxHp,
			["effectMaxHp"] = effectMaxHp,
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
		table.insert(DER.Gather.Data, entry)
		table.sort( DER.Gather.Data , function(x,y) return x.ms > y.ms end )
		truncateTable(DER.Gather.Data, 11)
	end
end
function DER.OnCombatStateChanged( eventCode ,  inCombat)
  if(inCombat) then
    DER.Gather.Data = {}
  end
end

 --[[ 
 * The slash command handler
 ]]-- 
function DER.Slash( text )

	-- Display the current version
	d( "You are using DeathReport version " .. DER.version .. "." )
end


function DER:RegisterEvents()
  -- Combat Events
  EVENT_MANAGER:RegisterForEvent( "DER" , EVENT_COMBAT_EVENT          , DER.OnCombatEvent )
  EVENT_MANAGER:RegisterForEvent( "DER" , EVENT_PLAYER_COMBAT_STATE, DER.OnCombatStateChanged)
end