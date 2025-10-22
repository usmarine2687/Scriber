--  scriber.lua - Kuhle 
--  updated 12/4/23
--  test update from git
--  Buys all available spells and tomes for specified level range (default is level 1 to current level)
--  It will not buy lower rank spells than you already have. If you have a Rk. II spell it will not buy a Rk. I of the same name, but would buy a Rk. III if available.
--  When finished buying or if no windows are open, it scribes every available spell/tome found in inventory (regardless of level range given)
--
--  It will loop and keep buying/scribing until all possible spells are processed or runs out of inventory space.
--
--  usage:
--     /lua run Scriber
--
--
--  credits:
--     The original scribe LUA written by Rouneq
--     The original scribe macro written by Sym with updates from Chatwiththisname and Sic


local mq = require('mq')
local Write = require('Scriber.Write')
local Vendlist = require('Scriber.Merchants')
require 'ImGui'

Write.prefix = 'Scribe'
Write.loglevel = 'info'

local Merchant_Open = mq.TLO.Merchant.Open
local Am_I_Moving = mq.TLO.Navigation.Active
local Am_I_Invis = mq.TLO.Me.Invis
local MyClassSN = mq.TLO.Me.Class.ShortName()
local MyClass = mq.TLO.Me.Class.Name()
local MyLevel = mq.TLO.Me.Level()
local MyDeity = mq.TLO.Me.Deity()
local TopInvSlot = 22 + mq.TLO.Me.NumBagSlots()
local MinLevel = 1
local MaxLevel = mq.TLO.Me.Level()
local scribe_level_range = {1, mq.TLO.Me.Level()}
local portsOnly = false
local DoLoop = true
local Scribing = false
local umbral = false
local cobalt = false
local stratos = false
local laurion = false
local hodstock = false
local Open, ShowUI = true, true
local stop_scribe = true
local selfbuy = false
local sendmehome = true
local levels_selected = false
local scribe_inv = false
local scribe_switch = true
local pause_switch = false
local buy_CloudyPots = true

local portKeyWords = {
	WIZ = {
		"Anchor Ring", "Anchor Push", "Teleport", "Translocate", "Gate", "Portal", "Alter Plane", "Evacuate", "Relocation"
	},
	DRU = {
		"Anchor Ring", "Anchor Push", "Teleport", "Ring of", "Circle of", "Zephyr", "Succor", "Wind of the"
	}
}
-- --------------------------------------------------------------------------------------------
-- SUB: Event_NotGold
-- --------------------------------------------------------------------------------------------
local function Event_NotGold()
	Scribing = false
	Write.Debug('Gold access needed')
end

-- --------------------------------------------------------------------------------------------
-- SUB: Event_FinishedScribing
-- --------------------------------------------------------------------------------------------
local function Event_FinishedScribing(_, spell)
	Scribing = false
	Write.Info('\aoFinished scribing/learning:\ag%s', spell)
end

mq.event('NotGold', "#*#you do not have at least a gold membership#*#", Event_NotGold)
mq.event('FinishedScribing', "#*#You have finished scribing #1#", Event_FinishedScribing)
mq.event('FinishedLearning', "#*#You have learned #1#!#*#", Event_FinishedScribing)

local function IsUsableByClass(item)
	local isUsable = false

	for i = 1, item.Classes() do
		if (item.Class(i)() == MyClass) then
			isUsable = true

			break
		end
	end

	return isUsable
end

local function IsUsableByDiety(item)
	local isUsable = item.Deities() == 0

	for i = 1, item.Deities() do
		if (item.Deity(i)() == MyDeity) then
			isUsable = true

			break
		end
	end

	return isUsable
end

local function IsScribed(spellName, spellId)
	local bookId = mq.TLO.Me.Book(spellName)()

	if (not bookId) then
		bookId = mq.TLO.Me.CombatAbility(spellName)()
	end

	if (not bookId) then
		return false
	end
	
	if (bookId and not spellId) then
		return true
	end

	return mq.TLO.Me.Book(bookId).ID() == spellId or mq.TLO.Me.CombatAbility(bookId).ID() == spellId
end

local function UsableInvetoryCount()
	local count = mq.TLO.Me.FreeInventory()

	-- See if there's an empty top inventory slot
	for pack = 23, TopInvSlot do
		local item = mq.TLO.Me.Inventory(pack)

		if (item.ID() and item.Container() > 0 and
			(item.Type() == "Quiver" or item.Type() == "Tradeskill Bag" or item.Type() == "Collectible Bag")) then
			count = count - item.Container() + item.Items()
		end
	end

	return count
end

-- --------------------------------------------------------------------------------------------
-- SUB: BuySpells
-- --------------------------------------------------------------------------------------------
local function BuySpells()
	if (not Merchant_Open() or mq.TLO.Merchant.Items() == 0) then
		return
	end

	mq.delay(2000)
	
	local index = 1
	local buyCount = 0

	while (index <= mq.TLO.Merchant.Items()) do
		if (UsableInvetoryCount() < 1 or not Merchant_Open()) then
			break
		end

		local merchantItem = mq.TLO.Merchant.Item(index)
		local spellName = merchantItem.Spell.Name()
		local spellId = merchantItem.Spell.ID()
		local type = merchantItem.Type()
		local spellLevel = merchantItem.Spell.Level()
		local buyPrice = merchantItem.BuyPrice()
		Write.Debug('index: %s', index)
		Write.Debug('spellName: %s', spellName)

		if (spellName) then
			spellName = spellName:gsub(' Rk. II', '')
			spellName = spellName:gsub(' Rk. III', '')
		end

		-- Write.Debug('type: %s', type)
		-- if ((type == 'Scroll' or type == 'Tome')) then
		-- 	Write.Debug('type: %d', type)
		-- 	Write.Debug('IsScribed: %s', IsScribed(spellName, spellId))
		-- end
		-- Write.Debug('buyPrice: %d', buyPrice)
		-- Write.Debug('mq.TLO.Me.Platinum(): %f', mq.TLO.Me.Platinum())
		-- Write.Debug('(buyPrice / 1000) < mq.TLO.Me.Platinum(): %s', (buyPrice / 1000) < mq.TLO.Me.Platinum())
		-- Write.Debug('mq.TLO.Me.Book(spellName)(): %s', mq.TLO.Me.Book(spellName)())
		-- Write.Debug('mq.TLO.Me.Book(spellName).ID(): %s', mq.TLO.Me.Book(spellName).ID)
		-- Write.Debug('not mq.TLO.Me.Book(spellName).ID(): %s', not mq.TLO.Me.Book(spellName).ID)
		-- Write.Debug('mq.TLO.Me.CombatAbility(spellName).ID(): %s', mq.TLO.Me.CombatAbility(spellName).ID)
		-- Write.Debug('not mq.TLO.Me.CombatAbility(spellName).ID(): %s', not mq.TLO.Me.CombatAbility(spellName).ID)
		-- Write.Debug('mq.TLO.FindItemCount(spellName)(): %d', mq.TLO.FindItemCount(spellName)())
		-- Write.Debug('mq.TLO.FindItemCount(spellName)() == 0: %s', mq.TLO.FindItemCount(spellName)() == 0)
		if ((type == 'Scroll' or type == 'Tome') and
			(spellLevel >= MinLevel and spellLevel <= MaxLevel) and
            (buyPrice / 1000) < mq.TLO.Me.Platinum() and
            (not IsScribed(spellName, spellId)) and 
            mq.TLO.FindItemCount(spellName)() == 0) then
			if (not IsUsableByClass(merchantItem)) then
				Write.Info('\arUnable to use \ag%s \arbecause of class restrictions', spellName)

				goto continue
			end

			if (IsScribed(spellName..' Rk. II') or mq.TLO.FindItemCount(spellName..' Rk. II')() > 0 or
                IsScribed(spellName..' Rk. III') or mq.TLO.FindItemCount(spellName..' Rk. III')() > 0) then
				Write.Info('\aoSkipping lower rank of \ar'..spellName)

			    goto continue
			end

			if (not IsUsableByDiety(merchantItem)) then
				Write.Info('\aoUnable to use \ar'..spellName..'\ao because of deity restrictions')
			    
				goto continue
			end
			
			if (portsOnly) then
				local isPort = false
				for index, str in pairs(portKeyWords[MyClassSN]) do
					if (string.find(spellName, str)) then
						isPort = true;
						break
					end
				end
				if (not isPort) then
					goto continue
				end
			end

			mq.TLO.Merchant.SelectItem("="..merchantItem.Name())
			mq.TLO.Merchant.Buy(1)

			mq.delay(1000)
			mq.doevents()

			buyCount = buyCount + 1
		end

::continue::

		index = index + 1

		if (index > mq.TLO.Merchant.Items()) then
			DoLoop = false
		end
	end

	if (buyCount == 0) then
		DoLoop = false
	end
end

local function GetItem(pack, slot)
	Write.Debug('GetItem pack: %s', tostring(pack))
	Write.Debug('GetItem slot: %s', tostring(slot))
	local item = nil

    if (pack) then
        item = mq.TLO.Me.Inventory(pack)
		Write.Debug('item (pack): %s', tostring(item))
    end

    if (slot and slot > -1) then
        item = item.Item(slot + 1)
		Write.Debug('item (pack/slot): %s', tostring(item))
    end

	return item
end

local function FindFreeInventory()
	local location = { pack = nil, slot = nil }

	-- See if there's an empty top inventory slot
	for pack = 23, TopInvSlot do
		Write.Debug('top pack: %s', tostring(location.pack))
		if (not mq.TLO.Me.Inventory(pack).ID()) then
			location.pack = pack

			Write.Debug('top pack: %s', tostring(location.pack))
			return location
		end
	end

	-- See if there's an empty bag slot
	for pack = 23, TopInvSlot do
        if (mq.TLO.Me.Inventory(pack).Container() > 0) then
			for slot = 1, mq.TLO.Me.Inventory(pack).Container() do
				if (not mq.TLO.Me.Inventory(pack).Item(slot).ID()) then
					location.pack = pack
					location.slot = slot - 1
		
					Write.Debug('bag pack: %s', tostring(location.pack))
					Write.Debug('bag slot: %s', tostring(location.slot))
					return location
				end
			end
        end
	end

	return nil
end

local function FormatPackLocation(pack, slot)
	local packLocation = ''

	if (slot and slot > -1) then
		packLocation = 'in '
	end

	packLocation = packLocation..'pack'..(pack - 22)

	if (slot and slot > -1) then
		packLocation = packLocation..' '..(slot + 1)
	end

	return packLocation
end

local function SeparateOutSingleItem(itemStack)
	if (UsableInvetoryCount() == 0) then
		return nil
	end

	local location = FindFreeInventory()

	if (not location) then
		return nil
	end

	local pickupCmd = '/ctrlkey /itemnotify '..FormatPackLocation(itemStack.ItemSlot(), itemStack.ItemSlot2())..' leftmouseup'
	local dropCmd = '/itemnotify '..FormatPackLocation(location.pack, location.slot)..' leftmouseup'

	mq.cmd(pickupCmd)

	mq.delay(3000, function ()
		return mq.TLO.Cursor.ID()
	end)

	mq.cmd(dropCmd)

	mq.delay(3000, function ()
		return not mq.TLO.Cursor.ID()
	end)

    local slot = location.slot

    if (slot) then
        slot = slot + 1
    end

	local item = GetItem(location.pack, slot)
	Write.Debug('location: %s', location)
	Write.Debug('new item from pack: %s, slot: %s', item.ItemSlot(), item.ItemSlot2())

	return item
end

local function OpenPack(item)
	Write.Debug('open pack')
	if (item and item.ItemSlot2() ~= nil and item.ItemSlot2() > -1) then
        local pack = GetItem(item.ItemSlot())

        if (pack.Open() == 0) then
            Write.Debug('try to open')
            local openCmd = '/itemnotify '..FormatPackLocation(item.ItemSlot())..' rightmouseup'
    
            mq.cmd(openCmd)

			mq.delay(3000, function ()
				return pack.Open() == 1
			end)
		end
	end
end

local function ClosePack(pack)
	Write.Debug('close pack')
	if (mq.TLO.Me.Inventory(pack).Open() == 1) then
		local closeCmd = '/itemnotify '..FormatPackLocation(pack)..' rightmouseup'

		mq.cmd(closeCmd)

		mq.delay(3000, function ()
			return not mq.TLO.Me.Inventory(pack).Open() == 0
		end)
	end
end

local function CheckPlugin(plugin)
	if mq.TLO.Plugin(plugin).IsLoaded() == false then
        mq.cmdf('/squelch /plugin %s noauto', plugin)
        Write.Debug('\aw%s\ar not detected! \aw This script requires it! Loading ...', plugin)
	end
end

local function OpenBook()

	mq.TLO.Window('SpellBookWnd').DoOpen()
end

local function CloseBook()
	if (mq.TLO.Window('SpellBookWnd').Open()) then
		mq.TLO.Window('SpellBookWnd').DoClose()
	end
end

-- --------------------------------------------------------------------------------------------
-- SUB: ScribeItem
-- --------------------------------------------------------------------------------------------
local function ScribeItem(item)
	local spellName = item.Spell.Name()
	local spellId = item.Spell.ID()
	Write.Info('\aoScribing \ag%s', spellName)

	OpenPack(item)
	OpenBook()

	mq.delay(200)

	local scribeCmd = '/itemnotify '..FormatPackLocation(item.ItemSlot(), item.ItemSlot2())..' rightmouseup'
	Write.Debug(scribeCmd)

	Scribing = true

	mq.cmd(scribeCmd)

	mq.delay(3000, function()
        return not Scribing
    end)

    Write.Debug('check for open confirmation dialog')
	if (mq.TLO.Window('ConfirmationDialogBox').Open() and 
		mq.TLO.Window('ConfirmationDialogBox').Child('CD_TextOutput').Text():find(mq.TLO.Cursor.Spell.Name()..' will replace')) then
        Write.Debug('click yes to confirm')
        mq.TLO.Window('ConfirmationDialogBox').Child('Yes_Button').LeftMouseUp()
    end

    mq.delay(15000, function ()
        Write.Debug('item is still scribing: %s', Scribing)
        return not Scribing
	end)

	if (mq.TLO.Cursor.ID()) then
        mq.cmd('/autoinv')
        mq.delay(200)
        mq.cmd('/autoinv')
    end
end

local function CheckAndScribe(pack, slot)
	local item = GetItem(pack, slot)

    if (item == nil) then
		Write.Info("\arDidn't find item in pack: \ag%s, \aoslot: \ag%s", pack, slot)

		return false
	end

	Write.Debug('item.Name(): %s', item.Name())
	-- Write.Debug('item.Type(): %s', item.Type())
	-- Write.Debug("item.Type() ~= 'Scroll': %s", item.Type() ~= 'Scroll')
	-- Write.Debug("item.Type() ~= 'Tome': %s", item.Type() ~= 'Tome')
	-- Write.Debug("(item.Type() ~= 'Scroll' and item.Type() ~= 'Tome'): %s", (item.Type() ~= 'Scroll' and item.Type() ~= 'Tome'))
	-- if ((item.Type() == 'Scroll' or item.Type() == 'Tome')) then
	-- 	Write.Debug('item.Spell.Level(): %d', item.Spell.Level())
	-- 	Write.Debug('MyLevel: %d', MyLevel)
	-- 	Write.Debug('item.Spell.Level() > MyLevel: %s', item.Spell.Level() > MyLevel)
		-- Write.Debug('item.Spell.ID(): %s', item.Spell.ID())
	-- 	Write.Debug('mq.TLO.Me.Book(item.Spell.ID()): %s', mq.TLO.Me.Book(item.Spell.ID())())
	-- 	Write.Debug('mq.TLO.Me.CombatAbility(item.Spell.ID()): %s', mq.TLO.Me.CombatAbility(item.Spell.ID())())
	-- end
	if ((item.Type() ~= 'Scroll' and item.Type() ~= 'Tome') or
		item.Spell.Level() > MyLevel or
		IsScribed(item.Spell.Name(), item.Spell.ID())) then
		Write.Debug('failed basic checks')

		return false
	end

	if (not IsUsableByClass(item)) then
		Write.Debug('not usable by class')

        return false
	end

	if (not IsUsableByDiety(item)) then
		Write.Debug('not usable by diety')

        return false
	end

	local spellName = item.Spell.Name()
	local spellRank = item.Spell.Rank()

	if (spellRank == 2 and
		(IsScribed(spellName..' Rk. III'))) then
		Write.Debug('already have a higher rank spell scribed')

		return false
	elseif (spellRank < 2 and
		(IsScribed(spellName..' Rk. II') or
		IsScribed(spellName..' Rk. III'))) then
		Write.Debug('already have a higher rank spell scribed')

		return false
	end

	if (item.StackCount() > 1) then
		item = SeparateOutSingleItem(item)
		Write.Debug('split item from pack: %s, slot: %s', item.ItemSlot(), item.ItemSlot2())
	end

	if (not item) then
		Write.Debug('no item to scribe')

		return false
	end

	ScribeItem(item)

	return true
end

-- --------------------------------------------------------------------------------------------
-- SUB: ScribeSpells
-- --------------------------------------------------------------------------------------------
local function ScribeSpells()
	Write.Info('\aoStarting to scribe spells in inventory')
	if (mq.TLO.Cursor.ID()) then
		mq.cmd('/autoinv')
	end

	--|** Opening your inventory for access bag slots **|
	if (not mq.TLO.Window('InventoryWindow').Open()) then
		mq.TLO.Window('InventoryWindow').DoOpen()
    end

	local scribeCount = 0

	-- Main inventory pack numers are 23-34. 33 & 34 come from add-on perks and may be active for the particular user
	for pack=23, TopInvSlot do
		--|** Check Top Level Inventory Slot to see if it has something in it **|
		if (mq.TLO.Me.Inventory(pack).ID()) then
			--|** Check Top Level Inventory Slot for bag/no bag **|
			if (mq.TLO.Me.Inventory(pack).Container() == 0) then
				--|** If it's not a bag do this **|
				if (CheckAndScribe(pack)) then
					scribeCount = scribeCount + 1
				end
			else
				--|** If it's a bag do this **|
				for slot=1,mq.TLO.Me.Inventory(pack).Container() do
					if (CheckAndScribe(pack, slot - 1)) then
						scribeCount = scribeCount + 1
					end
				end

				ClosePack(pack)
			end
		end
	end

	CloseBook()

	if (scribeCount == 0) then
		DoLoop = false
	end
end

local function EstablishMerchantMode(merchant)
	if not Merchant_Open() then
		if (not merchant and not mq.TLO.Target.ID()) then
			Write.Debug('Not currently in merchant mode')

			return
		end

		if (not mq.TLO.Target.ID()) then
			mq.TLO.Spawn(merchant).DoTarget()

			mq.delay(3000, function ()
				return mq.TLO.Target.Name() == merchant
			end)
		end

		mq.TLO.Merchant.OpenWindow()

		mq.delay(10000, function ()
			return mq.TLO.Merchant.ItemsReceived()
		end)

		if (not Merchant_Open()) then
			Write.Debug('Could not establish merchant mode')

			return
		end
	end

	return mq.TLO.Target.Name()
end


--------------------
--- Travel Stuff ---
--------------------

local GateClass = {'CLR', 'DRU', 'SHM', 'NEC', 'MAG', 'ENC', 'WIZ'}
local bindzones = {'poknowledge', 'guildlobby', 'moors', 'crescent'}
local walkingzone = {'guildlobby', 'moors', 'crescent'}

local function GetMyZone()
	return mq.TLO.Zone.ShortName():lower()
end

local function TableCheck(value, tbl)
    for _, item in ipairs(tbl) do
        if item == value then
            return true
        end
    end
    return false
end

local ituclickable = {'Fabled Bone Earring of Evasion', 'Bone Earring of Evasion', 'Potion of Deadishness'}

local function ITUClick()
	for _, item in ipairs(ituclickable) do
		local clicky = mq.TLO.FindItem(item)()
		if clicky ~= nil then
			Write.Info('\aoUsing \ag'..clicky)
			mq.cmdf('/useitem %s', clicky)
			mq.delay(5000, function()
				return Am_I_Invis('undead')()
			end)
            return
		end
	end
end

local ITU = {PAL = '1212', CLR = '1212', SHD = '1212', NEC = '1212', WIZ = '291',
MAG = '291', ENC = '291', BRD = '231'}

local function CastITU()
	local itu_id = ITU[MyClassSN]
	if mq.TLO.Me.Class.ShortName() == 'ROG' and mq.TLO.Me.Invis('SOS')() == false then
		if mq.TLO.Me.Sneaking() == false then
			mq.cmd('/doability sneak')
		end
		mq.cmd('/doability hide')
	end
    if itu_id then
        while not mq.TLO.Me.AltAbilityReady(ITU[MyClassSN]) do
            mq.delay(100)
        end
        mq.cmdf('/alt act %i', itu_id)
        mq.delay(5000, function()
            return Am_I_Invis('undead')()
        end)
	else
		if mq.TLO.Me.Invis('undead')() == false then
			ITUClick()
		end
	end
end

local invisclickable = {'Cloudy Potion', 'Philter of Shadows', 'Philter of Concealment', 'Potion: Spirit of the Mist Wolf', 'Potion of Windspeed', 'Essence of Concealment', 'Phase Spider Blood'}

local function InvisClick()
	if mq.TLO.Me.Invis() == false then
		for _, item in ipairs(invisclickable) do
			local clicky = mq.TLO.FindItem(item)()
			if clicky then
				Write.Info('\aoUsing \ag'..clicky)
				mq.cmdf('/useitem %s', clicky)
				mq.delay(5000, function()
					return Am_I_Invis('normal')()
				end)
            	return
			end
		end
	end
end

local Invis = {SHD = '531', NEC = '531', WIZ = '1210', MAG = '1210', ENC = '1210',
SHM = '3730', BST = '980', RNG = '80', DRU = '80', BRD = '231'}
local ClassInv = {'SHD', 'NEC', 'WIZ', 'MAG', 'ENC', 'SHM', 'BST', 'RNG', 'DRU', 'BRD'}

local function CastInvis()
	local invis_id = Invis[MyClassSN]
	if mq.TLO.Me.Class.ShortName() == 'ROG' and mq.TLO.Me.Invis('SOS')() == false then
		if mq.TLO.Me.Sneaking() == false then
			mq.cmd('/doability sneak')
		end
		mq.cmd('/doability hide')
	end
    if invis_id then
        while ClassInv and not mq.TLO.Me.AltAbilityReady(Invis[MyClassSN]) do
            mq.delay(100)
        end
        mq.cmdf('/alt act %i', invis_id)
        mq.delay(5000, function()
            return Am_I_Invis('normal')()
        end)
	else
        InvisClick()
    end
end



local function ETWKClass(tbl)
    for _, movers in ipairs(tbl) do
        if movers == MyClassSN then
			Write.Info('\arGoing Out of safe area area, watch your char for aggro!')
			mq.delay(1000)
            return true
        end
    end
    return false
end

local function OldBulwark()
	if mq.TLO.FindItemCount('Bulwark of Many Portals')() > 0 and mq.TLO.FindItem('Bulwark of Many Portals').Charges() < 1 then
		mq.cmd('/ctrl /itemnotify "Bulwark of Many Portals" leftmouseup')
		mq.delay(1000)
		mq.cmd('/destroy')
	end
end

local lmovers = {'NEC', 'ROG', 'WIZ', 'SHD'}
local umovers = {'DRU', 'SHA', 'BER', 'BST'}
local items = {'Drunkard\'s Stein', 'Brick of Knowledge', 'Staff of Guidance', 'Celestial Sword','The Fabled Binden Concerrentia', 'The Binden Concerrentia', 'Bulwark of Many Portals', 'Powered Clockwork Talisman', 'Small Clockwork Talisman', 'Philter of Major Translocation', 'Ethernere Travel Brew', 'Gate Potion'}
local HasItem = false
local function HaveItem()
	for _, item in pairs(items) do
		local clicky = mq.TLO.FindItem(item)()
		if clicky ~= nil then
			HasItem = true
			Write.Info('\agHave Item To Teleport Home \ap'..clicky)
			if clicky == 'Bulwark of Many Portals' then
				OldBulwark()
			end
		end
		if clicky == nil then
			Write.Info('\arDo not have \ap'..item)
		end
	end
end

local function HomeItem()
	for _, item in pairs(items) do
		local clicky = mq.TLO.FindItem(item)()
		if clicky ~= nil then
			Write.Info('\aoUsing: \ap'..clicky)
			mq.cmdf('/useitem "%s"',clicky)
			mq.delay('5s')
			while mq.TLO.Me.Casting() do mq.delay(100) end
			break
		end
	end
end

local function doGate()
	local is_gate_ready = mq.TLO.Me.AltAbilityReady('Gate')
	while not is_gate_ready() do
	  mq.delay(250)
	end
	mq.cmdf('/alt act %s',mq.TLO.Me.AltAbility('Gate')())
	mq.delay(2500)
end

local function Travelto(zone)
	while Am_I_Moving() == false do
		mq.cmdf('/travelto %s', zone)
		mq.delay(5000)
	end
end

-- Let's do Rouneq part of the build --

local function Rouneq()
    local merchant
    
    while DoLoop do
        merchant = EstablishMerchantMode(merchant)
		mq.delay(3000)
		if (GetMyZone() == 'ethernere') and (ETWKClass(lmovers) == true) and (mq.TLO.Me.Class.ShortName() == ('DRU' or 'WIZ')) then
            CastInvis()
			mq.delay(1000)
            while not Am_I_Invis('normal')() do
                Write.Info("\arYou're stuck in a loop because you're not invis!")
                mq.delay(5000)
            end
            mq.cmd('/nav loc -2041.47 -1923.51 -206.41')
            while Am_I_Moving() do
                mq.delay(50)
            end
        end
        if (GetMyZone() == 'ethernere') and (ETWKClass(umovers) == true) and (mq.TLO.Me.Class.ShortName() == ('DRU' or 'WIZ')) then
            CastInvis()
			mq.delay(1000)
            while not Am_I_Invis('normal')() do
                Write.Info("\arYou're stuck in a loop because you're not invis!")
                mq.delay(5000)
            end
            mq.cmd('/nav loc -1134.32 -1631.03 -262.38')
            while Am_I_Moving() do
                mq.delay(50)
            end
        end

        if Merchant_Open() then
			if (portsOnly) then
				Write.Info('\aoBuying only \ag'..MyClass..'\ao port spells for levels \ag'..MinLevel..'\ao to \ag'..MaxLevel)
			else
				Write.Info('\aoBuying all \ag'..MyClass..'\ao spells/tomes for levels \ag'..MinLevel..'\ao to \ag'..MaxLevel)
			end

            BuySpells()

            mq.TLO.Window('MerchantWnd').DoClose()
            
            mq.delay(3000, function ()
                return not Merchant_Open()
            end)
        end
		Write.Info('\aoScribing Spells')
        ScribeSpells()
    end
end

-- Time to go home --
local function Home()
	Write.Info('\aoTrying to go Home')
	if TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) then
		mq.cmdf('/itemtarget "Shabby Lobby Door"')
		mq.cmd('/nav item')
		while mq.TLO.Navigation.Active() do
			mq.delay(1000)
		end
		mq.cmd("/click right item")
		mq.delay(5000, function() return mq.TLO.Menu.Name() == "Shabby Lobby Door" end)
		mq.cmdf('/squelch /notify "Open the Door to the Lobby" menuselect')
		while GetMyZone() ~= "guildlobby" do
			mq.delay(1000)
		end
		mq.delay(1000)
	end
	if sendmehome then
		if TableCheck(GetMyZone(), bindzones) == false then
			mq.delay(300)
			if TableCheck(MyClassSN, GateClass) then
				doGate()
				mq.delay(10000, function() return TableCheck(GetMyZone(), bindzones) end)
				while TableCheck(GetMyZone(), bindzones) == false do
					doGate()
				end
			else
				HaveItem()
				if HasItem then
					HomeItem()
					return
				else
				 	if not HasItem then
						if mq.TLO.Me.AltAbilityReady('Throne of Heroes')() then
						Write.Info('Trying to cast TOH')
						mq.cmd('/alt act 511')
						mq.delay(20000, function() return mq.TLO.Me.Casting.ID() == nil end)
						else
						Write.Info('Using Origin AA to get to your origin home')
						mq.delay(1080000, function() return mq.TLO.Me.AltAbilityReady('Origin')() == true end)
						mq.cmd('/alt act 331')
						mq.delay(20000, function() return mq.TLO.Me.Casting.ID() == nil end)
						end
					end
				end
				mq.delay(2000)
				while TableCheck(GetMyZone(), bindzones) == false do
					Write.Info('You\'re current zone is \ag%s', GetMyZone())
					Write.Info('\arCould not find a method to teleport back to home')
					Write.Info('If you feel this is an error, please report it to Kuhle in Discord or the discussion thread.')
					mq.delay(15000)
				end
			end
		end
		Write.Info('Exiting Home function')
		
	end
end

-- Walking distance --
local function TravSafe()
    if TableCheck(GetMyZone(), walkingzone) == true then
        Write.Info('\aoYour close enough, lets walk to \agPOKnowledge')
        Travelto('poknowledge')
        --traveling, please wait--
        while Am_I_Moving() do
            mq.delay(50)
        end
        mq.delay(50)
        while GetMyZone() ~= 'poknowledge' do
            mq.delay(1500)
        end
		mq.delay(1000)
    end
end

-- Loop Function
local function Vendloop()
	if GetMyZone() == 'poknowledge' then
		mq.delay(1000)
		Write.Info('\aoVerified \ag%s', GetMyZone())
		Write.Info('\aoMin level is \ag%s', MinLevel)
		Write.Info('\aoMax level is \ag%s', MaxLevel)
		for merch, minmaxtable in pairs(Vendlist[GetMyZone()][MyClassSN]) do
			if (minmaxtable.vendormax >= MinLevel) and (minmaxtable.vendormin <= MaxLevel) then
				Write.Info('Naving to \ag%s', merch)
				mq.cmdf('/nav spawn npc %s', merch)
					--traveling, please wait --
				while Am_I_Moving() do
					if (mq.TLO.Spawn(merch).Distance3D() < 20) then
						mq.cmd('/nav stop')
					end
					mq.delay(50)
				end
				if (mq.TLO.Spawn(merch).Distance3D() < 30) then
					Write.Info('\aoTargeting \ag%s', merch)
					mq.cmdf('/target %s', merch)
					mq.delay(1500)
					Write.Info('\aoClicking \ag%s', merch)
					mq.cmd('/click right target')
				end
				while not Merchant_Open() do
					mq.delay(500)
				end
				if selfbuy then
					Write.Info('\aoYou may now buy your spells. We will continue moving when you \arclose the merchant window.')
					while Merchant_Open() do
						mq.delay(500)
					end
				else
					Rouneq()
				end
				
				mq.delay(1000)
				DoLoop = true
			end
		end
	else
        if (GetMyZone() == 'ethernere') and (ETWKClass(lmovers) == true) then
            CastInvis()
			mq.delay(1000)
            while not Am_I_Invis('normal')() do
                Write.Info("\arYou're stuck in a loop because you're not invis!")
                mq.delay(5000)
            end
            mq.cmd('/nav loc -2041.47 -1923.51 -206.41')
            while Am_I_Moving() do
                mq.delay(50)
            end
        end
        if (GetMyZone() == 'ethernere') and (ETWKClass(umovers) == true) then
            CastInvis()
			mq.delay(1000)
            while not Am_I_Invis('normal')() do
                Write.Info("\arYou're stuck in a loop because you're not invis!")
                mq.delay(5000)
            end
            mq.cmd('/nav loc -1134.32 -1631.03 -262.38')
            while Am_I_Moving() do
                mq.delay(50)
            end
        end
		for _, merch in ipairs(Vendlist[GetMyZone()][MyClassSN]) do
			if GetMyZone() == 'stratos' then
				CastInvis()
				mq.delay(1000)
				while not Am_I_Invis('normal')() do
					Write.Info("\arYou're stuck in a loop because you're not invis!")
					mq.delay(5000)
				end
			end
			Write.Info('\aoNaving to \ag%s', merch)
			mq.cmdf('/nav spawn npc %s', merch)
				--traveling, please wait --
			while Am_I_Moving() do
				if (mq.TLO.Spawn(merch).Distance3D() < 20) then
					mq.cmd('/nav stop')
				end
				mq.delay(50)
			end
			if (mq.TLO.Spawn(merch).Distance3D() < 30) then
				Write.Info('\aoTargeting \ag%s', merch)
				mq.cmdf('/target %s', merch)
				mq.delay(1500)
				Write.Info('\aoOpening vendor window for \ag%s', merch)
				mq.cmd('/click right target')
			end
			while not Merchant_Open() do
				mq.delay(3000)
			end
			if selfbuy then
				while Merchant_Open() do
					mq.delay(3000)
				end
			else
				Rouneq()
			end
			
			mq.delay(1500)
			DoLoop = true
		end
	end
end

-- pok buying
local function Trav(area)
    if GetMyZone() == area then
		Write.Info('\arVerifying \ag'..area..' \aolocation, please hold')
		if GetMyZone() == 'shardslanding' then
			Write.Info('\aoNaving to a spot to properly function')
			mq.cmd('/nav loc 337.82 142.24 3.12')
			while Am_I_Moving() do
				mq.delay(1000)
			end
		end
		if GetMyZone() == 'cobaltscartwo' then
			CastInvis()
			mq.delay(1000)
			while not Am_I_Invis('normal')() do
				Write.Info("\arYou're stuck in a loop because you're not invis!")
				mq.delay(5000)
			end
		end
        mq.delay(500)
		Write.Info('\aoSafe location verified, beginning Vendor Travel')
        Vendloop()
    end
end

local function guildhall(loc)
	local PortalSetter_Running = mq.TLO.PortalSetter.InProgress
	if TableCheck(GetMyZone(), { loc, "guildhall"}) == false then
		Travelto('guildhall')
		while GetMyZone() ~= 'guildhall' do
			mq.delay(5000)
		end
		mq.delay(1000)
	end
	if GetMyZone() == 'guildhall' then
        Write.Info('\aoSetting portal to \ag%s', loc)
		mq.cmd('/nav spawn npc zeflmin werlikanin')
		while Am_I_Moving() do
			mq.delay(50)
		end
		mq.cmd('/target zeflmin werlikanin')
		mq.cmd('/click right target')
		while not Merchant_Open() do
			mq.delay(3000)
		end
		mq.cmdf('/portalsetter %s', loc)
		mq.delay(10000)
		while PortalSetter_Running() do
			mq.delay(1000)
		end
        mq.delay(5000)
        Write.Info('\aoMoving to portal')
		mq.cmd('/nav loc -22.73 -132.26 3.88')
		while Am_I_Moving() do
			mq.delay(1000)
		end
		while not mq.TLO.Window('LargeDialogWindow').Open() do
			mq.delay(500)
		end
		mq.TLO.Window('LargeDialogWindow').Child('LDW_YesButton').LeftMouseUp()
			mq.delay(1000)
        if GetMyZone() ~= loc then
            Write.Info("\arPortalSetter either didn't finish or someone changed the portal before you ported. You are supposed to be in \ag%s", loc)
		    while GetMyZone() ~= loc do
			    mq.delay(1000)
            end
			mq.delay(1000)
		end
	end
end
local function TravWW()
	if (GetMyZone() == 'cobaltscartwo') then
		CastInvis()
		mq.delay(1000)
		while not Am_I_Invis('normal')() do
			Write.Info("\arYou're stuck in a loop because you're not invis, please go to Western Wastes")
			mq.delay(5000)
			if GetMyZone() == 'westwastestwo' then
				goto westwastesstart
			end
		end
		mq.cmd('/nav loc -238.15 -236.38 58.35')
		while Am_I_Moving() do
			mq.delay(50)
		end
		if not Am_I_Invis('normal')() then
			CastInvis()
		end
		mq.delay(1000)
		mq.cmd('/nav loc 1084.45 1139.67 54.51')
		while Am_I_Moving() do
			mq.delay(50)
		end
		CastInvis()
		mq.delay(1000)
		while not Am_I_Invis('normal')() do
			Write.Info("\arYou're stuck in a loop because you're not invis, please go to Western Wastes")
			mq.delay(5000)
			if GetMyZone() == 'westwastestwo' then
				goto westwastesstart
			end
		end
		Travelto('westwastestwo')
		Write.Info('\arMesh in CS to WW is not perfect, if you get stuck, please head to Western Wastes')
		while GetMyZone() ~= 'westwastestwo' do
			mq.delay(1000)
		end
		mq.delay(1000)
	end
	::westwastesstart::
	CastITU()
	mq.delay(1000)
	while (mq.TLO.Me.Invis('undead')() == false) or (mq.TLO.Spawn('Olwen').Distance3D() < 50) do
		Write.Info('\arNeed to be ITU to get to vendors or manaully walk near \agOlwen')
		mq.delay(5000)
	end
	Vendloop()
end

-- --------------------------------------------------------------------------------------------
-- SUB: Need Potions
-- --------------------------------------------------------------------------------------------
local PotClass = {'WAR', 'CLR', 'MNK', 'BER', 'PAL'}
local pots = 'Cloudy Potion'
local function NeedPotions()
	if buy_CloudyPots then
		for i = 1, #PotClass do
			if mq.TLO.Me.Class.ShortName() == PotClass[i] and mq.TLO.FindItemCount(14514)() < 20 then
				if  mq.TLO.Zone.ID() ~= 202 then
					print('You need Cloudy Potions')
					Travelto('Poknowledge')
					while mq.TLO.Navigation.Active() do
						mq.delay(10)
					end
				end
			if mq.TLO.Zone.ID() == 202 then
				mq.cmd('/nav spawn Mirao Frostpouch')
				while mq.TLO.Navigation.Active() do
					mq.delay(10)
				end
				mq.cmd('/tar Mirao Frostpouch')
				mq.delay(1000)
				mq.cmd('/usetarget')
				mq.delay(1000)
				mq.TLO.Merchant.SelectItem('=' .. pots)
				mq.delay(1000)
				mq.TLO.Merchant.Buy(20)
				mq.delay(1000)
				mq.TLO.Merchant.Buy(20)
				mq.cmd('/notify MerchantWnd "MW_Done_Button" leftmouseup')
					if mq.TLO.FindItemCount(14514)() > 1 then
						print('Much Safer With Cloudy Potions')
					end
				end
			end
		end
	end
end


-- --------------------------------------------------------------------------------------------
-- SUB: Travel to the zones (Meat which starts the potatoes)
-- --------------------------------------------------------------------------------------------

local function POK()
    if (MinLevel <= 90) and (MaxLevel >= 1) == true then
        Home()
        TravSafe()
        Trav('poknowledge')
    end
end
local function Arg()
    if ((MinLevel <= 95) and (MaxLevel >= 91)) == true then
        guildhall('argath')
        Trav('argath')

        --Going back to Guild Lobby for next Zone--
        Home()
    end
end
local function Sha()
    if ((MinLevel <= 100) and (MaxLevel >= 96)) == true then
        guildhall('shardslanding')
        Trav('shardslanding')

        --Going back to Guild Lobby for next Zone--
        Home()
    end
end
local function ETWK()
    if ((MinLevel <= 100) and (MaxLevel >= 96)) == true then
        guildhall('ethernere')
        Trav('ethernere')

        --Going back to Guild Lobby for next Zone--
        Home()
    end
end

local function Kat()
    if ((MinLevel <= 105) and (MaxLevel >= 101)) == true then
        guildhall('kattacastrumb')
        Trav('kattacastrumb')

        --Going back to Guild Lobby for next Zone--
        Home()
    end
end

local function POT()
    if ((MinLevel <= 105) and (MaxLevel >= 101)) == true then
        Travelto('potranquility')
		while GetMyZone() ~= 'potranquility' do
			mq.delay(1000)
		end
		mq.delay(1000)
        Trav('potranquility')

        --Going back to Guild Lobby for next Zone--
        Travelto('guildlobby')
		while GetMyZone() ~= 'guildlobby' do
			mq.delay(1000)
		end
		mq.delay(1000)
    end
end

local function Lcea()
    if (((MinLevel <= 105) and (MaxLevel >= 101)) == true) or ((MyClassSN == 'BST') and ((MinLevel <= 79) and (MaxLevel >= 79))) or ((MyClassSN == 'SHM') and ((MinLevel <= 74) and (MaxLevel >= 74))) then
        guildhall('lceanium')
        Trav('lceanium')

        --Going back to Guild Lobby for next Zone--
        Home()
    end
end

local function OT2()
    if ((MinLevel <= 110) and (MaxLevel >= 106)) == true then
        guildhall('overtheretwo')
        Trav('overtheretwo')

        --Going back to Guild Lobby for next Zone--
        Home()
    end
end

local function Strat()
    if ((MinLevel <= 110) and (MaxLevel >= 106)) == true then
		if stratos then
			Travelto('guildhalllrg')
			while TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) ~= true do
				mq.delay(1000)
			end
			if TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) then
				mq.cmdf('/itemtarget "Stratos Fire Platform"')
				mq.cmd('/nav item')
				while mq.TLO.Navigation.Active() do
					mq.delay(100)
				end
				mq.cmd("/click right item")
				mq.delay(5000, function() return mq.TLO.Menu.Name() == "Stratos Fire Platform" end)
				mq.cmdf('/squelch /notify "Teleport to Stratos" menuselect')
			end
			while GetMyZone() ~= 'stratos' do
				mq.delay(1000)
			end
			mq.delay(1000)
		else
			Travelto('stratos')
			while GetMyZone() ~= 'stratos' do
				mq.delay(1000)
			end
			mq.delay(1000)
		end
        Trav('stratos')
		CastInvis()
		mq.delay(1000)
		while not Am_I_Invis('normal')() do
			Write.Info("\arYou're stuck in a loop because you're not invis!")
			CastInvis()
			mq.delay(5000)
		end
        --Going back to Guild Lobby for next Zone--
		Travelto('guildlobby')
		while GetMyZone() ~= 'guildlobby' do
			mq.delay(1000)
		end
		mq.delay(1000)
    end
end
local function EW2()
	print('Enter EW2')
    if ((MinLevel <= 115) and (MaxLevel >= 111)) == true then
        guildhall('eastwastestwo')
        Trav('eastwastestwo')
        --Going back to Guild Lobby for next Zone--
		if ((mq.TLO.Me.Class.ShortName() ~= 'DRU') or (mq.TLO.Me.Class.ShortName() ~= 'WIZ')) == true then
        Home()
		end
    end
	print('Exit EW2')
end

local function GD2()
	print('Enter GD2')
	if (((MinLevel <= 115) and (MaxLevel >= 111) == true) and mq.TLO.Me.Class.ShortName() == 'DRU') or (((MinLevel <= 115) and (MaxLevel >= 111) == true) and mq.TLO.Me.Class.ShortName() == 'WIZ') then
		if mq.TLO.Me.Zone.ShortName() ~= 'eastwastestwo' then
			guildhall('eastwastestwo')
		end
		CastInvis()
		mq.delay(1000)
		while not Am_I_Invis('normal')() do
			Write.Info("\arYou're stuck in a loop because you're not invis!")
			mq.delay(5000)
		end
		Travelto('greatdividetwo')
		while mq.TLO.Navigation.Active() do
			mq.delay(50)
		end
		Trav('greatdividetwo')
		Home()
	end
	print('Exit GD2')
end

local function CS2()
	if mq.TLO.Me.HaveExpansion(27)() == false then
		Write.Info("\arYou do not have the expansion for this zone!")
		mq.cmd('/lua stop scriber')
	end
    if (((MinLevel <= 115) and (MaxLevel >= 111) == true) and mq.TLO.Me.Class.ShortName() == 'DRU') or (((MinLevel <= 115) and (MaxLevel >= 111) == true) and mq.TLO.Me.Class.ShortName() == 'WIZ') then
		if cobalt then
			Travelto('guildhalllrg')
			while TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) ~= true do
				mq.delay(50)
			end
			--may keep going if not a large guild hall--
			mq.cmd('/nav stop')
			if TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) then
				mq.cmdf('/itemtarget "Skyshrine Dragon Brazier"')
				mq.cmd('/nav item')
				while mq.TLO.Navigation.Active() do
					mq.delay(100)
				end
				mq.cmd("/click right item")
				mq.delay(5000, function() return mq.TLO.Menu.Name() == "Skyshrine Dragon Brazier" end)
				mq.cmdf('/squelch /notify "Teleport to Cobalt Scar" menuselect')
			end
			while GetMyZone() ~= 'cobaltscartwo' do
				mq.delay(1000)
			end
			mq.delay(1000)
		else
        	guildhall('cobaltscartwo')
		end
		--Teleport Classes are special--
        if mq.TLO.Me.Class.ShortName() == 'WIZ' or mq.TLO.Me.Class.ShortName() == 'DRU' then
			Trav('cobaltscartwo')
		end
    end
end
local function WW2()
	if mq.TLO.Me.HaveExpansion(27)() == false then
		Write.Info("\arYou do not have the expansion for this zone!")
		mq.cmd('/lua stop scriber')
	end
    if (MinLevel <= 115) and (MaxLevel >= 111) == true then
		guildhall('cobaltscartwo')
        TravWW()
		Home()
    end
end
local function ME2()
	if mq.TLO.Me.HaveExpansion(28)() == false then
		Write.Info("\arYou do not have the expansion for this zone!")
		mq.cmd('/lua stop scriber')
	end
	if (MinLevel <= 120) and (MaxLevel >= 116) == true then
		if umbral then
			if mq.TLO.FindItemCount(165381)() > 0 and mq.TLO.Me.ItemReady(165381)() then
				mq.cmd('/useitem umbral plains mushroom')
				mq.delay(1000)
				while mq.TLO.Me.Casting() and GetMyZone() ~= 'umbral' do
					mq.delay(1000)
				end
				mq.delay(1000)
			else
				Travelto('guildhalllrg')
				while TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) ~= true do
					mq.delay(1000)
				end
				--may keep going if not a large guild hall--
				mq.cmd('/nav stop')
					if TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) then
						mq.cmdf('/itemtarget "Umbral Plains Scrying Bowl"')
						mq.cmd('/nav item')
					while mq.TLO.Navigation.Active() do
						mq.delay(100)
					end
					mq.cmd("/click right item")
					mq.delay(5000, function() return mq.TLO.Menu.Name() == "Umbral Plains Scrying Bowl" end)
					mq.cmdf('/squelch /notify "Teleport to Umbral Plains" menuselect')
				end
				while GetMyZone() ~= 'umbral' do
					mq.delay(1000)
				end
				mq.delay(1000)
			end
			Travelto('maidentwo')
			while GetMyZone() ~= 'maidentwo' do
				mq.delay(1000)
			end
			mq.delay(1000)
		else
			guildhall('maidentwo')
		end
        Trav('maidentwo')
		Home()
    end
end
local function SVD()
	if mq.TLO.Me.HaveExpansion(29)() == false then
		Write.Info("\arYou do not have the expansion for this zone!")
		mq.cmd('/lua stop scriber')
	end
	if (MinLevel <= 120) and (MaxLevel >= 116) == true then
		guildhall('sharvahltwo')
        Trav('sharvahltwo')
		Home()
    end
end
local function LIN()
	if mq.TLO.Me.HaveExpansion(30)() == false then
		Write.Info("\arYou do not have the expansion for this zone!")
		mq.cmd('/lua stop scriber')
	end
	if (MinLevel <= 125) and (MaxLevel >= 121) == true then
		if laurion then
			if mq.TLO.FindItemCount(151183)() > 0 and mq.TLO.Me.ItemReady(151183)() then
				mq.cmd("/useitem laurion inn lute")
				mq.delay(1000)
				while mq.TLO.Me.Casting() and GetMyZone() ~= 'laurioninn' do
					mq.delay(1000)
				end
				mq.delay(1000)
			else
				Travelto('guildhalllrg')
				while TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) ~= true do
					mq.delay(1000)
				end
				mq.delay(1000)
				--may keep going if not a large guild hall--
				mq.cmd('/nav stop')
					if TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) then
						mq.cmdf([[/itemtarget "Laurion's Door"]])
						mq.cmd('/nav item')
					while mq.TLO.Navigation.Active() do
						mq.delay(100)
					end
					mq.cmd("/click right item")
					mq.delay(5000, function() return mq.TLO.Menu.Name() == "Laurion's Door" end)
					mq.cmdf([[/squelch /notify "Teleport to Laurion Inn" menuselect]])
				end
				while GetMyZone() ~= 'laurioninn' do
					mq.delay(1000)
				end
				mq.delay(1000)
			end
		else
			guildhall('laurioninn')
		end
		Trav('laurioninn')
		Home()
	end
end
local function HOD()
	if mq.TLO.Me.HaveExpansion(31)() == false then
		Write.Info("\arYou do not have the expansion for this zone!")
		mq.cmd('/lua stop scriber')
	end
	if (MinLevel <= 125) and (MaxLevel >= 121) == true then
		if hodstock then
			if mq.TLO.FindItemCount(174135)() > 0 and mq.TLO.Me.ItemReady(174135)() then
				mq.cmd("/useitem Aureate Figurine")
				mq.delay(1000)
				while mq.TLO.Me.Casting() and GetMyZone() ~= 'hodstock' do
					mq.delay(1000)
				end
				mq.delay(1000)
			else
				mq.cmd('/travelto guildhalllrg')
				while TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) ~= true do
					mq.delay(1000)
				end
				mq.delay(1000)
				--may keep going if not a large guild hall--
				mq.cmd('/nav stop')
					if TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) then
						mq.cmdf([[/itemtarget "Aureate Dragon Ring"]])
						mq.cmd('/nav item')
					while mq.TLO.Navigation.Active() do
						mq.delay(100)
					end
					mq.cmd("/click right item")
					mq.delay(5000, function() return mq.TLO.Menu.Name() == "Aureate Dragon Ring" end)
					mq.cmdf([[/squelch /notify "Teleport to Hodstock Hills" menuselect]])
				end
				while GetMyZone() ~= 'hodstock' do
					mq.delay(1000)
				end
				mq.delay(1000)
			end
		else
			guildhall('hodstock')
		end
		Trav('hodstock')
		Home()
	end
end
local function TOE()
	if (((MinLevel <= 125) and (MaxLevel >= 120) == true) and mq.TLO.Me.Class.ShortName() == 'DRU') or (((MinLevel <= 125) and (MaxLevel >= 120) == true) and mq.TLO.Me.Class.ShortName() == 'WIZ') then
		if mq.TLO.Me.HaveExpansion(31)() == false then
			Write.Info("\arYou do not have the expansion for this zone!")
			mq.cmd('/lua stop scriber')
		else
			if hodstock then
				if mq.TLO.FindItemCount(174135)() > 0 and mq.TLO.Me.ItemReady(174135)() then
					mq.cmd("/useitem Aureate Figurine")
					mq.delay(1000)
					while mq.TLO.Me.Casting() and GetMyZone() ~= 'hodstock' do
						mq.delay(1000)
				end
					mq.delay(1000)
				else
					mq.cmd('/travelto guildhalllrg')
					while TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) ~= true do
						mq.delay(1000)
					end
					mq.delay(1000)
					--may keep going if not a large guild hall--
					mq.cmd('/nav stop')
						if TableCheck(GetMyZone(), {'guildhalllrg_int', 'guildhallsml', 'guildhall3'}) then
							mq.cmdf([[/itemtarget "Aureate Dragon Ring"]])
							mq.cmd('/nav item')
						while mq.TLO.Navigation.Active() do
							mq.delay(100)
						end
						mq.cmd("/click right item")
						mq.delay(5000, function() return mq.TLO.Menu.Name() == "Aureate Dragon Ring" end)
						mq.cmdf([[/squelch /notify "Teleport to Hodstock Hills" menuselect]])
					end
					while GetMyZone() ~= 'hodstock' do
						mq.delay(1000)
					end
					mq.delay(1000)
				end
			else
				guildhall('hodstock')
			end
			mq.cmd('/nav spawn npc "Torin')
			while Am_I_Moving() do
				mq.delay(1000)
			end
			mq.cmd('/target Torin')
			mq.delay(1000)
			mq.cmd('/say get on')
			while not mq.TLO.Zone.ShortName() == 'toe' do
				mq.delay(1000)
			end
			Trav('toe')
			Home()
		end
	end
end


local spell_locations = {
	{
		name = 'Plane of Knowledge',
		min_level = 1,
		max_level = 90,
		selected = true,
		action = POK
	}, {
		name = 'Argath',
		min_level = 91,
		max_level = 95,
		selected = true,
		action = Arg
	}, {
		name = 'Shards Landing',
		min_level = 96,
		max_level = 100,
		selected = true,
		action = Sha
	}, {
		name = 'Ethernere',
		min_level = 96,
		max_level = 100,
		selected = true,
		action = ETWK
	}, {
		name = 'Katta Deluge',
		min_level = 101,
		max_level = 105,
		selected = true,
		action = Kat
	}, {
		name = 'Plane of Tranquility',
		min_level = 101,
		max_level = 105,
		selected = true,
		action = POT
	}, {
		name = 'Lceanium',
		min_level = 74,
		max_level = 105,
		selected = true,
		action = Lcea
	}, {
		name = 'Overthere',
		min_level = 106,
		max_level = 110,
		selected = true,
		action = OT2
	}, {
		name = 'Stratos',
		min_level = 106,
		max_level = 110,
		selected = true,
		action = Strat
	}, {
		name = 'Eastern Wastes',
		min_level = 111,
		max_level = 115,
		selected = true,
		action = EW2
	}, {
		name = 'Great Divide',
		min_level = 111,
		max_level = 115,
		selected = true,
		action = GD2
	}, {
		name = 'Cobalt Scar',
		min_level = 111,
		max_level = 115,
		selected = true,
		action = CS2
	}, {
		name = 'Western Wastes',
		min_level = 111,
		max_level = 115,
		selected = true,
		action = WW2
	}, {
		name = "Maiden's Eye",
		min_level = 116,
		max_level = 120,
		selected = true,
		action = ME2
	}, {
		name = "Shar Vahl, Divided",
		min_level = 116,
		max_level = 120,
		selected = true,
		action = SVD
	}, {
		name = "Laurion Inn",
		min_level = 121,
		max_level = 125,
		selected = true,
		action = LIN
	}, {
		name = "Hodstock",
		min_level = 121,
		max_level = 125,
		selected = true,
		action = HOD
	}, {
		name = "Eternity",
		min_level = 121,
		max_level = 125,
		selected = true,
		action = TOE
	}
}

local function scriber(min, max)

	if mq.TLO.Macro() then
        Write.Info('\a-yTemporarily pausing macros before we act')
        mq.cmd('/squelch /mqp on')
    end

    if (mq.TLO.CWTN ~= nil) then
        Write.Info('\a-yTemporarily pausing CWTN Plugins before we act')
        mq.cmd('/squelch /docommand /${Me.Class.ShortName} pause on')
    end

    if mq.TLO.Me.Class() == 'bard' and mq.TLO.Plugin('mq2twist')() then
        Write.Info('\a-yTemporarily pausing bard twist and bardswap effects')
        mq.cmd('/squelch /twist stop')
    end

	for _, value in ipairs(spell_locations) do
		if min ~= nil and max ~= nil then
			MinLevel = min
			MaxLevel = max
		end
		if value.min_level <= MaxLevel and value.max_level >= MinLevel and value.selected == true then
			value.action()
		end
	end
	stop_scribe = true
end

local function scriberhelp()
	Write.Info("Welcome to Scriber. Here are the following available commands to use with Scriber. /sc or /scriber cmd")
	Write.Info("'/scriber 75' for single level scribing or '/sc 75 80' for multiple level scribing")
	Write.Info("Help - shows this information you are currently seeing")
	Write.Info("Status - Shows the current selections")
	Write.Info("gui/ui/show - Shows or closes the UI")
	Write.Info("Return - to return or not return to POK/guild lobby")
	Write.Info("Cloudy - turns on and off buying cloudy potions (WAR, CLR, MNK, BER, PAL classes only)")
	Write.Info("Buy - turns selfbuy on/off")
	Write.Info("Umbral/Cobalt/Stratos/Laurion/Hodstock - Turns on and off the respective guild hall clickies or keyrings")
end

local function bind_scriber(cmd, cmd2)
	if cmd == nil or cmd == "help" then
		scriberhelp()
		return
	end
	if cmd == "status" then

		if Open then
			Write.Info("UI - Open")
		else
			Write.Info("UI - Closed")
		end

		if buy_CloudyPots then
			Write.Info("Buy Cloudy pots - on")
		else
			Write.Info("Buy Cloudy pots - off")
		end
		if portsOnly then
			Write.Info("Only scribe ports - on")
		else
			Write.Info("Only scribe ports - off")
		end

		if sendmehome then
			Write.Info("Return - On")
		else
			Write.Info("Return - Off")
		end

		if selfbuy then
			Write.Info("Selfbuy - On")
		else
			Write.Info("Selfbuy - Off")
		end
		if umbral then
			Write.Info("Umbral Plains - On")
		else
			Write.Info("Umbral Plains - Off")
		end
		if cobalt then
			Write.Info("Cobalt Scar - On")
		else
			Write.Info("Cobalt Scar - Off")
		end
		if stratos then
			Write.Info("Stratos - On")
		else
			Write.Info("Stratos - Off")
		end
		if laurion then
			Write.Info("Laurion Inn - On")
		else
			Write.Info("Laurion Inn - Off")
		end
		if hodstock then
			Write.Info("Hodstock - On")
		else
			Write.Info("Hodstock - Off")
		end
	end

	if cmd == "gui" or cmd == "ui" or cmd == "show" then
		Open = not Open
		if Open then
			Write.Info("UI - Open")
		else
			Write.Info("UI - Closed")
		end
		return
	end

	if cmd == "cloudy" then
		buy_CloudyPots = not buy_CloudyPots
		if buy_CloudyPots then
			Write.Info("Buy Cloudy pots - on")
		else
			Write.Info("Buy Cloudy pots - off")
		end
		return
	end

	if cmd == "return" then
		sendmehome = not sendmehome
		if sendmehome then
			Write.Info("Return - On")
		else
			Write.Info("Return - Off")
		end
		return
	end

	if cmd == "buy" then
		selfbuy = not selfbuy
		if selfbuy then
			Write.Info("Selfbuy - On")
		else
			Write.Info("Selfbuy - Off")
		end
		return
	end

	if cmd == "scribe" then
		scribe_inv = true
		scribe_switch = false
	end

	if cmd == "Umbral" or cmd =="Cobalt" or cmd == "Stratos" or cmd == "Laurion" or cmd == "Hodstock" then
		if cmd == "umbral" then
			umbral = not umbral
			if umbral then
				Write.Info("Umbral Plains - On")
			else
				Write.Info("Umbral Plains - Off")
			end
		elseif cmd == "Cobalt" then
			cobalt = not cobalt
			if cobalt then
				Write.Info("Cobalt Scar - On")
			else
				Write.Info("Cobalt Scar - Off")
			end
		elseif cmd == "Stratos" then
			stratos = not stratos
			if stratos then
				Write.Info("Stratos - On")
			else
				Write.Info("Stratos - Off")
			end
		elseif cmd == "Laurion" then
			laurion = not laurion
			if laurion then
				Write.Info("Laurion Inn - On")
			else
				Write.Info("Laurion Inn - Off")
			end
		else
			if cmd == "Hodstock" then
				hodstock = not hodstock
				if hodstock then
					Write.Info("Hodstock Hills - On")
				else
					Write.Info("Hodstock Hills - Off")
				end
			end
		end
	end

	if tonumber(cmd) ~= nil and tonumber(cmd2) == nil then
        cmd2 = tonumber(cmd)
		cmd = tonumber(cmd)
        scriber(cmd, cmd2)
        return
    else
		if tonumber(cmd) ~= nil and tonumber(cmd2) ~= nil then
			cmd = tonumber(cmd)
			cmd2 = tonumber(cmd2)
    		scriber(cmd, cmd2)
		end
        return
    end
end

local function setup()
	mq.bind('/scriber', bind_scriber)
	mq.bind('/sc', bind_scriber)
end
CheckPlugin('MQ2PortalSetter')
CheckPlugin('MQ2Nav')
CheckPlugin('MQ2EasyFind')

local function set_location_options(locations, range)
	for _, value in ipairs(locations) do
	   if (range[1] > value.max_level) or (range[2] < value.min_level) then
		  value.selected = false
	   else
		  value.selected = true
	   end
	end
end

local function ScriberGUI()
    if Open then
		ImGui.SetWindowSize(500, 500, ImGuiCond.Once)
		Open, ShowUI = ImGui.Begin('Scriber - Letting us do the work for you, one spell at a time! (v4.0.0)', Open)
		if ShowUI then
			scribe_level_range, levels_selected = ImGui.SliderInt2("Levels of Scribing", scribe_level_range, 1, 125)
			if levels_selected then set_location_options(spell_locations, scribe_level_range) end
			if ((scribe_level_range[1] > scribe_level_range[2]) or (scribe_level_range[2] < scribe_level_range[1])) then scribe_level_range[1] = scribe_level_range[2] end
			if scribe_switch then
				if ImGui.Button('Start Scribing') then
					MaxLevel = scribe_level_range[2]
					MinLevel = scribe_level_range[1]
					pause_switch = false
					stop_scribe = false
					scribe_switch = false
				end
				ImGui.SameLine()
				if ImGui.Button('End Scriber') then
					mq.cmd('/lua stop scriber')
				end
				if ImGui.Button('Scribe spells currently in inventory') then
					scribe_inv = true
					scribe_switch = false
				end
			end
			if not scribe_switch then
				if ImGui.Button('Pause Scriber') then
					pause_switch = true
					scribe_switch = true
				end
				ImGui.SameLine()
				if ImGui.Button('End Scriber') then
					mq.cmd('/lua stop scriber')
				end
			end
			if ImGui.CollapsingHeader('Basic Options') then
				selfbuy = ImGui.Checkbox("I want to buy my own spells", selfbuy)
				sendmehome = ImGui.Checkbox("Send me to my bind point", sendmehome)
				buy_CloudyPots = ImGui.Checkbox("Buy Cloudy Potions", buy_CloudyPots)
				ImGui.BeginDisabled(not (MyClassSN == "DRU" or MyClassSN == "WIZ"))
					portsOnly = ImGui.Checkbox("Only purchase and scribe portal type spells (wiz/dru only)", portsOnly)
				ImGui.EndDisabled()
			end
			if ImGui.CollapsingHeader('Guildhall clicky and Keyring Options') then
				if ImGui.BeginTable("GuildClicky",2) then
					ImGui.TableNextColumn() umbral = ImGui.Checkbox("Umbral Plains Scrying Bowl", umbral)
					ImGui.TableNextColumn() cobalt = ImGui.Checkbox("Skyshrine Dragon Brazier", cobalt)
					ImGui.TableNextColumn() stratos = ImGui.Checkbox("Stratos Fire Platform", stratos)
					ImGui.TableNextColumn() laurion = ImGui.Checkbox("Laurion's Door", laurion)
					ImGui.TableNextColumn() hodstock = ImGui.Checkbox("Aureate Dragon Ring", hodstock)
					ImGui.EndTable()
				end
			end
			if ImGui.CollapsingHeader('Zone Specific Options') then
				if ImGui.BeginTable("Zone Selections",2) then
					for _, value in ipairs(spell_locations) do
						ImGui.TableNextColumn()
						value.selected = ImGui.Checkbox(value.name, value.selected)
						ImGui.SameLine()
						ImGui.TextDisabled(string.format('(%d-%d)', value.min_level, value.max_level))
					end
				ImGui.EndTable()
				end
			end
		end
		ImGui.End()
    end
end
local function pause_script()
	while pause_switch do
		mq.delay(1000)
	end
end
local start_scribing = coroutine.create(function()
	NeedPotions()
	scriber()
	scribe_switch = true
	stop_scribe = true
end)

local inv_scribe = coroutine.create(function()
	while DoLoop do
		Write.Info('Starting to scribe spells in inventory')
		ScribeSpells()
	end
	Write.Info('No more spells to scribe in Inventory')
	scribe_switch = true
	scribe_inv = false
end)
mq.imgui.init('ScriberGUI', ScriberGUI)
setup()
Write.Info("Welcome to Scriber, Please use the commands '/scriber help' if further instructions are needed")
while true do
	pause_script()
	mq.doevents()
	if not stop_scribe then
		coroutine.resume(start_scribing)
	end
	if scribe_inv then
		coroutine.resume(inv_scribe)
	end
	mq.delay(20)
end
