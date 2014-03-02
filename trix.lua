if select(2, UnitClass('PLAYER')) ~= 'ROGUE' then return DisableAddOn('Trix') end

Trix = {}
Trix.CombatUpdate = {}

-- [[ Event handler ]] --
local mod = CreateFrame('Frame')
mod:SetScript('OnEvent', function(self, event, ...)
	Trix[event](Trix, ...)
end)

-- [[ Utility ]] --
local print = function(msg)
	print(format('|cffFF0000Trix|r %s', msg))
end

local ColorTable
local ClassColorByName = function(name)
	local r, g, b, colors = 1, 1, 1
	-- bool to fix strupper/strlower errors with ASCII characters
	name = strlower(name) or name
	name = gsub(name, '^%a', strupper(strmatch(name, '^%a'))) or name
	
	if name == UnitName('target') then
		colors = ColorTable[select(2, UnitClass('target'))]
		r, g, b = colors.r, colors.g, colors.b
	end
	
	for i = 1, GetNumPartyMembers() do
		if name == UnitName('party'..i) then
			colors = ColorTable[select(2, UnitClass('party'..i))]
			r, g, b = colors.r, colors.g, colors.b
		end
	end

	for i = 1, GetNumRaidMembers() do
		if name == UnitName('raid'..i) then
			colors = ColorTable[select(2, UnitClass('raid'..i))]
			r, g, b = colors.r, colors.g, colors.b
		end
	end
	
	return format('|cff%02x%02x%02x%s', r * 255, g * 255, b * 255, name)
end

local UpdateTrixUnit = function(macro, unit)
	if not InCombatLockdown() then
		EditMacro(macro, nil, nil, format('#showtooltip\n/cast [@%s] Tricks of the Trade', unit))
		print(format('Editing macro %s - %s', macro, ClassColorByName(unit)))
	else
		Trix.CombatUpdate.Macro = macro
		Trix.CombatUpdate.Unit = unit
		print('Currently in combat. Macro will be edited automatically once out of combat.')
		mod:Show()
	end
end

local ServerChannels = {}
local PopulateServerChannelList = function()
	wipe(ServerChannels)
	for i = 1, select('#', EnumerateServerChannels()) do
		ServerChannels[select(i, EnumerateServerChannels())] = true
	end
end

local CustomChannels = {}
local PopulateCustomChannelList = function()
	wipe(CustomChannels)
	PopulateServerChannelList()
	for i = 1, select('#', GetChannelList()) do
		if i % 2 == 1 then
			local name = select(i + 1, GetChannelList())
			if not ServerChannels[name] then
				CustomChannels[select(i, GetChannelList())] = name
			end
		end
	end
end

-- [[ OnUpdate for automatic editing after combat exit ]] --
local last, throttle = 0, .5
mod:SetScript('OnUpdate', function(self, elapsed)
	last = last + elapsed
	if last >= throttle then
		if not InCombatLockdown() then
			UpdateTrixUnit(Trix.CombatUpdate.Macro, Trix.CombatUpdate.Unit)
			last = 0
			mod:Hide()
		end
		last = 0
	end
end)
mod:Hide()

-- [[ Slash command handler ]] --
SlashCmdList['TRIX'] = function(message)
	local whichMacro, whichUnit = message:match("^(%S*)%s*(.-)$")
	if whichMacro ~= '1' and whichMacro ~= '2' then
		InterfaceOptionsFrame_OpenToCategory('Trix')
	else
		whichUnit = strlower(whichUnit) == 't' and UnitName('target') or whichUnit
		UpdateTrixUnit('Trix'..whichMacro, whichUnit)
	end
end
SLASH_TRIX1 = '/trix'

-- [[ Option defaults ]] --
local defaults = {
	announce = false,
	message = 'Tricks of the Trade on >>%s<<',
	channel = 'PARTY',
}

-- [[ Event stuff ]] --
mod:RegisterEvent('ADDON_LOADED')
function Trix:ADDON_LOADED(addon)
	if addon == 'Trix' then
		TrixDB = TrixDB or {}
		for option, value in pairs(defaults) do
			if not TrixDB[option] then TrixDB[option] = value end
		end
	
		Trix.Options.Announce:SetChecked(TrixDB.announce or 0)
		
		UIDropDownMenu_SetSelectedValue(Trix.Options.Announce.Channel, TrixDB.channel or "PARTY")
		
		Trix.Options.Announce.Message:SetText(TrixDB.message)
		Trix.Options.Announce.Message:SetCursorPosition(0)
	end
end

mod:RegisterEvent('PLAYER_ENTERING_WORLD')
function Trix:PLAYER_ENTERING_WORLD()
	-- !ClassColors support.
	ColorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	
	local _, numCharacter
	for i = 1, 2 do
		if not GetMacroInfo('Trix'..i) then
			_, numCharacter = GetNumMacros()
			CreateMacro('Trix'..i, 1, '#showtooltip\n/cast [@] Tricks of the Trade', numCharacter < MAX_CHARACTER_MACROS and 1 or 0)
		end
	end
	
	if not GetMacroInfo('TrixAIO') then
		_, numCharacter = GetNumMacros()
		CreateMacro('TrixAIO', 1, '#showtooltip Tricks of the Trade\n/cast [help][@focus, help][@targettarget, help] Tricks of the Trade', numCharacter < MAX_CHARACTER_MACROS and 1 or 0)
	else
		-- compatability with the new @unit macro syntax.
		EditMacro('TrixAIO', nil, nil, gsub(GetMacroBody("TrixAIO"), "target=", "@"))
	end
end

mod:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
function Trix:COMBAT_LOG_EVENT_UNFILTERED(_, subEvent, sourceGUID, _, _, _, destName, _, spellId)
	if subEvent == 'SPELL_CAST_SUCCESS' and sourceGUID == UnitGUID('player') and spellId == 57934 and TrixDB.announce then
		if TrixDB.channel == 'WHISPER' then
			SendChatMessage(format(TrixDB.message, 'you'), 'WHISPER', nil, destName)
		elseif TrixDB.channel == 'SMART' then
			if GetNumRaidMembers() > 0 then
				SendChatMessage(format(TrixDB.message, destName), 'RAID')
			elseif GetNumPartyMembers() > 0 then
				SendChatMessage(format(TrixDB.message, destName), 'PARTY')
			end
		elseif TrixDB.channel == 'PARTY' or TrixDB.channel == 'RAID' then
			SendChatMessage(format(TrixDB.message, destName), TrixDB.channel)
		else
			SendChatMessage(format(TrixDB.message, destName), 'CHANNEL', nil, TrixDB.channel)
		end
	end
end

-- [[ Options menu stuff ]] --
local channels = {
	'Party',
	'Raid',
	'Whisper',
	'Smart',
}
PopulateCustomChannelList()

Trix.Options = CreateFrame('Frame', nil, UIParent)
Trix.Options.name = 'Trix'
InterfaceOptions_AddCategory(Trix.Options)

Trix.Options.Title = Trix.Options:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
Trix.Options.Title:SetText('Trix')
Trix.Options.Title:SetPoint('TOPLEFT', 15, -15)

Trix.Options.Announce = CreateFrame('CheckButton', nil, Trix.Options, 'OptionsCheckButtonTemplate')
Trix.Options.Announce:SetPoint('TOPLEFT', 15, -75)
Trix.Options.Announce:SetScript('PostClick', function(self)
	TrixDB.announce = self:GetChecked()
end)

Trix.Options.Announce.Text = Trix.Options.Announce:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
Trix.Options.Announce.Text:SetText('Announce casts to chat')
Trix.Options.Announce.Text:SetPoint('LEFT', Trix.Options.Announce, 'RIGHT', 5, 0)

Trix.Options.Announce.Channel = CreateFrame('Frame', 'TrixDropDown', Trix.Options, 'UIDropDownMenuTemplate')
Trix.Options.Announce.Channel:SetPoint('LEFT', Trix.Options.Announce.Text, 'RIGHT', 5, 0)

Trix.Options.Announce.Message = CreateFrame('EditBox', nil, Trix.Options)
Trix.Options.Announce.Message:SetHeight(20)
Trix.Options.Announce.Message:SetWidth(320)
Trix.Options.Announce.Message:SetAutoFocus(false)
Trix.Options.Announce.Message:SetFontObject('GameFontNormalSmall')
Trix.Options.Announce.Message:SetTextColor(1, 1, 1)
Trix.Options.Announce.Message:SetPoint('TOPLEFT', Trix.Options.Announce, 'BOTTOMLEFT', 0, -10)
Trix.Options.Announce.Message:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
Trix.Options.Announce.Message:SetScript('OnEnterPressed', function(self) TrixDB.message = self:GetText() self:ClearFocus() end)

Trix.Options.Announce.Message.bg = Trix.Options.Announce.Message:CreateTexture(nil, 'BACKGROUND')
Trix.Options.Announce.Message.bg:SetTexture(0, 0, 0, .4)
Trix.Options.Announce.Message.bg:SetAllPoints()

local InitializeDropdown = function()
	local info = UIDropDownMenu_CreateInfo()
	for _, channel in pairs(channels) do		
		info.text = channel
		info.value = strupper(channel)
		info.func = function(self)
			UIDropDownMenu_SetSelectedValue(Trix.Options.Announce.Channel, self.value)
			TrixDB.channel = self.value
		end
		info.checked = nil
		UIDropDownMenu_AddButton(info, 1)
	end

	for index, channel in pairs(CustomChannels) do
		info.text = channel
		info.value = index
		info.func = function(self)
			UIDropDownMenu_SetSelectedValue(Trix.Options.Announce.Channel, self.value)
			TrixDB.channel = self.value
		end
		info.checked = nil
		UIDropDownMenu_AddButton(info, 1)
	end
end
UIDropDownMenu_Initialize(Trix.Options.Announce.Channel, InitializeDropdown)

mod:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE')
function Trix:CHAT_MSG_CHANNEL_NOTICE()
	PopulateCustomChannelList()
	UIDropDownMenu_Initialize(Trix.Options.Announce.Channel, InitializeDropdown)
	Trix:ADDON_LOADED('Trix')
end