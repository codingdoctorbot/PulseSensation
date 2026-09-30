# Forever UI source excerpts backing the plan

Source tree: `docs/DevelopmentplusReference/Developer Documents/WOW SOURCECODE/wow-ui-source-forever/` (written `<forever-src>/`). `version.txt` reads: `1.60.1.69913`.
Each block is a verbatim excerpt, prefixed with its source line number. Plan section in brackets.

## ITEM_PUSH payload [P1.2]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua` lines 155,166

```lua
  155  		{
  156  			Name = "ItemPush",
  157  			Type = "Event",
  158  			LiteralName = "ITEM_PUSH",
  159  			SynchronousEvent = true,
  160  			Payload =
  161  			{
  162  				{ Name = "bagSlot", Type = "luaIndex", Nilable = false },
  163  				{ Name = "iconFileID", Type = "number", Nilable = false },
  164  			},
  165  		},
  166  		{
```

## LOOT_OPENED carries autoLoot; LOOT_READY carries autoloot [P1.2]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua` lines 217,237

```lua
  217  		{
  218  			Name = "LootOpened",
  219  			Type = "Event",
  220  			LiteralName = "LOOT_OPENED",
  221  			SynchronousEvent = true,
  222  			Payload =
  223  			{
  224  				{ Name = "autoLoot", Type = "bool", Nilable = false },
  225  				{ Name = "isFromItem", Type = "bool", Nilable = false },
  226  			},
  227  		},
  228  		{
  229  			Name = "LootReady",
  230  			Type = "Event",
  231  			LiteralName = "LOOT_READY",
  232  			SynchronousEvent = true,
  233  			Payload =
  234  			{
  235  				{ Name = "autoloot", Type = "bool", Nilable = false },
  236  			},
  237  		},
```

## LOOT_SLOT_CLEARED(lootSlot) [P1.2]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua` lines 258,267

```lua
  258  		{
  259  			Name = "LootSlotCleared",
  260  			Type = "Event",
  261  			LiteralName = "LOOT_SLOT_CLEARED",
  262  			SynchronousEvent = true,
  263  			Payload =
  264  			{
  265  				{ Name = "lootSlot", Type = "luaIndex", Nilable = false },
  266  			},
  267  		},
```

## CHAT_MSG_LOOT payload: 12th field is the looter GUID [P1.2]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua` lines 1814,1834

```lua
 1814  		{
 1815  			Name = "ChatMsgLoot",
 1816  			Type = "Event",
 1817  			LiteralName = "CHAT_MSG_LOOT",
 1818  			SynchronousEvent = true,
 1819  			Payload =
 1820  			{
 1821  				{ Name = "text", Type = "cstring", Nilable = false },
 1822  				{ Name = "playerName", Type = "cstring", Nilable = false },
 1823  				{ Name = "languageName", Type = "cstring", Nilable = false, NeverSecret = true },
 1824  				{ Name = "channelName", Type = "cstring", Nilable = false, NeverSecret = true },
 1825  				{ Name = "playerName2", Type = "cstring", Nilable = false },
 1826  				{ Name = "specialFlags", Type = "cstring", Nilable = false, NeverSecret = true },
 1827  				{ Name = "zoneChannelID", Type = "number", Nilable = false, NeverSecret = true },
 1828  				{ Name = "channelIndex", Type = "number", Nilable = false, NeverSecret = true },
 1829  				{ Name = "channelBaseName", Type = "cstring", Nilable = false, NeverSecret = true },
 1830  				{ Name = "languageID", Type = "number", Nilable = false, NeverSecret = true },
 1831  				{ Name = "lineID", Type = "number", Nilable = false, NeverSecret = true },
 1832  				{ Name = "guid", Type = "WOWGUID", Nilable = false },
 1833  				{ Name = "bnSenderID", Type = "number", Nilable = false },
 1834  				{ Name = "isMobile", Type = "bool", Nilable = false, NeverSecret = true },
```

## GetLootSlotInfo returns incl. locked (6th), isQuestItem (7th), isCoin (10th) [P1.2]

`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua` lines 232,238

```lua
  232  
  233  function LootFrameMixin:Open()
  234  	local dataProvider = CreateDataProvider();
  235  	for slotIndex = 1, GetNumLootItems() do
  236  		local texture, item, quantity, currencyID, itemQuality, locked, isQuestItem, questID, isActive, isCoin = GetLootSlotInfo(slotIndex);
  237  
  238  		if currencyID then
```

## Blizzard loot frame reads autoLoot from LOOT_OPENED [P1.2]

`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua` lines 131,135

```lua
  131  function LootFrameMixin:OnEvent(event, ...)
  132  	if event == "LOOT_OPENED" then
  133  		local isAutoLoot, acquiredFromItem = ...;
  134  		self.isAutoLoot = isAutoLoot;
  135  		self.acquiredFromItem = acquiredFromItem;
```

## Enum.ItemQuality has no quest tier [P1.2]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemQualitiesDocumentation.lua` lines 1,22

```lua
    1  local ItemQualities =
    2  {
    3  	Tables =
    4  	{
    5  		{
    6  			Name = "ItemQuality",
    7  			Type = "Enumeration",
    8  			NumValues = 9,
    9  			MinValue = 0,
   10  			MaxValue = 8,
   11  			Fields =
   12  			{
   13  				{ Name = "Poor", Type = "ItemQuality", EnumValue = 0 },
   14  				{ Name = "Common", Type = "ItemQuality", EnumValue = 1 },
   15  				{ Name = "Uncommon", Type = "ItemQuality", EnumValue = 2 },
   16  				{ Name = "Rare", Type = "ItemQuality", EnumValue = 3 },
   17  				{ Name = "Epic", Type = "ItemQuality", EnumValue = 4 },
   18  				{ Name = "Legendary", Type = "ItemQuality", EnumValue = 5 },
   19  				{ Name = "Artifact", Type = "ItemQuality", EnumValue = 6 },
   20  				{ Name = "Heirloom", Type = "ItemQuality", EnumValue = 7 },
   21  				{ Name = "WoWToken", Type = "ItemQuality", EnumValue = 8 },
   22  			},
```

## Personal repair: RepairAllItems(), GetRepairAllCost [P1.3]

`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/MerchantFrame.xml` lines 214,235

```lua
  214  				<Scripts>
  215  					<OnEnter>
  216  						GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
  217  						local repairAllCost, canRepair = GetRepairAllCost();
  218  						if ( canRepair and (repairAllCost > 0) ) then
  219  							GameTooltip:SetText(REPAIR_ALL_ITEMS);
  220  							GameTooltip_AddMoneyLine(GameTooltip, repairAllCost);
  221  						end
  222  						GameTooltip:Show();
  223  					</OnEnter>
  224  					<OnLeave function="GameTooltip_Hide"/>
  225  					<OnClick>
  226  						RepairAllItems();
  227  						PlaySound(SOUNDKIT.ITEM_REPAIR);
  228  						GameTooltip:Hide();
  229  					</OnClick>
  230  					<OnEvent>
  231  						local _, canRepair = GetRepairAllCost();
  232  						if ( not canRepair ) then
  233  							MerchantRepairAllIcon:SetDesaturated(true);
  234  							MerchantGuildBankRepairButtonIcon:SetDesaturated(true);
  235  							MerchantGuildBankRepairButton:Disable();
```

## Guild-funded repair: RepairAllItems(true), CanGuildBankRepair [P1.3]

`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/MerchantFrame.xml` lines 296,326

```lua
  296  						GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
  297  						local repairAllCost, canRepair = GetRepairAllCost();
  298  						if ( canRepair and (repairAllCost > 0) ) then
  299  							GameTooltip:SetText(REPAIR_ALL_ITEMS);
  300  							GameTooltip_AddMoneyLine(GameTooltip, repairAllCost);
  301  							local amount = GetGuildBankWithdrawMoney();
  302  							local guildBankMoney = GetGuildBankMoney();
  303  							if ( amount == -1 ) then
  304  								-- Guild leader shows full guild bank amount
  305  								amount = guildBankMoney;
  306  							else
  307  								amount = min(amount, guildBankMoney);
  308  							end
  309  							GameTooltip:AddLine(GUILDBANK_REPAIR, nil, nil, nil, true);
  310  							GameTooltip_AddHighlightLine(GameTooltip, MoneyFormatterUtil.FormatMoney(amount, MoneyFormatterPresets.ShowLowerWithZero))
  311  							GameTooltip:Show();
  312  						end
  313  					</OnEnter>
  314  					<OnLeave function="GameTooltip_Hide"/>
  315  					<OnClick>
  316  						--FIXME!!! Need actual amount of guild money left to withdraw
  317  						if(CanGuildBankRepair()) then
  318  							RepairAllItems(true);
  319  							PlaySound(SOUNDKIT.ITEM_REPAIR);
  320  						end
  321  						GameTooltip:Hide();
  322  					</OnClick>
  323  					<OnEvent>
  324  						local _, canRepair = GetRepairAllCost();
  325  						if ( not canRepair ) then
  326  							MerchantRepairAllIcon:SetDesaturated(true);
```

## Repair cursor: InRepairMode [P1.3]

`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/MerchantFrame.lua` lines 74,78

```lua
   74  	end
   75  	if ( MerchantRepairItemButton:IsShown() ) then
   76  		if ( InRepairMode() ) then
   77  			MerchantRepairItemButton:LockHighlight();
   78  		else
```

## INVENTORY_ALERT_STATUS_SLOTS (11 slots) and the alert events [P1.3]

`<forever-src>/Interface/AddOns/Blizzard_DurabilityFrame/DurabilityFrame.lua` lines 1,27

```lua
    1  INVENTORY_ALERT_STATUS_SLOTS = {};
    2  INVENTORY_ALERT_STATUS_SLOTS[1] = {slot = "Head"};
    3  INVENTORY_ALERT_STATUS_SLOTS[2] = {slot ="Shoulders"};
    4  INVENTORY_ALERT_STATUS_SLOTS[3] = {slot ="Chest"};
    5  INVENTORY_ALERT_STATUS_SLOTS[4] = {slot ="Waist"};
    6  INVENTORY_ALERT_STATUS_SLOTS[5] = {slot ="Legs"};
    7  INVENTORY_ALERT_STATUS_SLOTS[6] = {slot ="Feet"};
    8  INVENTORY_ALERT_STATUS_SLOTS[7] = {slot ="Wrists"};
    9  INVENTORY_ALERT_STATUS_SLOTS[8] = {slot ="Hands"};
   10  INVENTORY_ALERT_STATUS_SLOTS[9] = {slot ="Weapon", showSeparate = 1};
   11  INVENTORY_ALERT_STATUS_SLOTS[10] = {slot ="Shield", showSeparate = 1};
   12  INVENTORY_ALERT_STATUS_SLOTS[11] = {slot ="Ranged", showSeparate = 1};
   13  
   14  INVENTORY_ALERT_COLORS = {};
   15  INVENTORY_ALERT_COLORS[1] = {r = 1, g = 0.82, b = 0.18};
   16  INVENTORY_ALERT_COLORS[2] = {r = 0.93, g = 0.07, b = 0.07};
   17  
   18  DurabilityFrameMixin = {};
   19  
   20  function DurabilityFrameMixin:OnLoad()
   21  	self:SetFrameLevel(self:GetFrameLevel() - 1);
   22  	self:RegisterEvent("UPDATE_INVENTORY_ALERTS");
   23  	self:RegisterEvent("PLAYER_ENTERING_WORLD");
   24  end
   25  
   26  function DurabilityFrameMixin:OnEvent()
   27  	self:SetAlerts();
```

## Blizzard reads GetInventoryAlertStatus(index): 1 yellow, 2 red [P1.3]

`<forever-src>/Interface/AddOns/Blizzard_DurabilityFrame/DurabilityFrame.lua` lines 57,90

```lua
   57  	local numAlerts = 0;
   58  	local texture, color, showDurability;
   59  	local hasLeft, hasRight;
   60  	self.anyItemBroken = false;
   61  	for index, value in pairs(INVENTORY_ALERT_STATUS_SLOTS) do
   62  		texture = _G["Durability"..value.slot];
   63  		if ( value.slot == "Shield" ) then
   64  			if ( C_PaperDollInfo.OffhandHasWeapon() ) then
   65  				DurabilityShield:Hide();
   66  				texture = DurabilityOffWeapon;
   67  			else
   68  				DurabilityOffWeapon:Hide();
   69  				texture = DurabilityShield;
   70  			end
   71  		end
   72  
   73  		color = INVENTORY_ALERT_COLORS[GetInventoryAlertStatus(index)];
   74  		if ( color ) then
   75  			texture:SetVertexColor(color.r, color.g, color.b, 1.0);
   76  			if ( value.showSeparate ) then
   77  				if ( value.slot == "Shield" or value.slot == "Ranged" ) then
   78  					hasRight = true;
   79  				elseif ( value.slot == "Weapon" ) then
   80  					hasLeft = true;
   81  				end
   82  				texture:Show();			
   83  			else
   84  				showDurability = 1;
   85  			end
   86  			numAlerts = numAlerts + 1;
   87  			if ( GetInventoryAlertStatus(index) == 2 ) then
   88  				self.anyItemBroken = true;
   89  			end
   90  		else
```

## Open All Mail: one attachment per step, OPEN_ALL_MAIL_MIN_DELAY = 0.15 [P0.2 S6]

`<forever-src>/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua` lines 1510,1545

```lua
 1510  local OPEN_ALL_MAIL_MIN_DELAY = 0.15;
 1511  
 1512  OpenAllMailMixin = {};
 1513  
 1514  function OpenAllMailMixin:Reset()
 1515  	self.mailIndex = 1;
 1516  	self.attachmentIndex = ATTACHMENTS_MAX;
 1517  	self.timeUntilNextRetrieval = nil;
 1518  	self.failedItemIDs = nil;
 1519  end
 1520  
 1521  function OpenAllMailMixin:StartOpening()
 1522  	self:Reset();
 1523  	self:Disable();
 1524  
 1525  	C_Mail.SetOpeningAll(true);
 1526  
 1527  	self:SetText(OPEN_ALL_MAIL_BUTTON_OPENING);
 1528  	self:RegisterEvent("MAIL_INBOX_UPDATE");
 1529  	self:RegisterEvent("MAIL_FAILED");
 1530  	self.numToOpen = GetInboxNumItems();
 1531  	self:AdvanceAndProcessNextItem();
 1532  end
 1533  
 1534  function OpenAllMailMixin:StopOpening()
 1535  	self:Reset();
 1536  	self:Enable();
 1537  
 1538  	C_Mail.SetOpeningAll(false);
 1539  
 1540  	self:SetText(OPEN_ALL_MAIL_BUTTON);
 1541  	self:UnregisterEvent("MAIL_INBOX_UPDATE");
 1542  	self:UnregisterEvent("MAIL_FAILED");
 1543  end
 1544  
 1545  function OpenAllMailMixin:ShouldSkipCurrentMail()
```

## Blizzard_MailFrame toc: AllowLoadGameType mainline (whether Forever loads it is unverified) [P0.2 S6]

`<forever-src>/Interface/AddOns/Blizzard_MailFrame/Blizzard_MailFrame.toc` lines 1,8

```lua
    1  ## Title: Blizzard_MailFrame
    2  ## Author: Blizzard Entertainment
    3  ## DefaultState: enabled
    4  ## Dependencies: Blizzard_FriendsFrame
    5  ## AllowLoad: Game
    6  ## AllowLoadGameType: mainline
    7  MailFrame.lua
    8  MailFrame.xml
```

## debugprofilestop is relative to the last debugprofilestart [P0.2]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua` lines 527,541

```lua
  527  		{
  528  			Name = "debugprofilestart",
  529  			Type = "Function",
  530  			Documentation = { "Starts a timer for profiling. The final time can be obtained by calling debugprofilestop." },
  531  		},
  532  		{
  533  			Name = "debugprofilestop",
  534  			Type = "Function",
  535  			Documentation = { "Returns the time in milliseconds since the last debugprofilestart call." },
  536  
  537  			Returns =
  538  			{
  539  				{ Name = "elapsedMilliseconds", Type = "number", Nilable = false },
  540  			},
  541  		},
```

## GetTimePreciseSec exists [P0.2]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua` lines 25,34

```lua
   25  		},
   26  		{
   27  			Name = "GetTimePreciseSec",
   28  			Type = "Function",
   29  
   30  			Returns =
   31  			{
   32  				{ Name = "time", Type = "number", Nilable = false },
   33  			},
   34  		},
```

## C_Container.CalculateTotalNumberOfFreeBagSlots is a C API [P1.1]

`<forever-src>/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua` lines 9,20

```lua
    9  	{
   10  		{
   11  			Name = "CalculateTotalNumberOfFreeBagSlots",
   12  			Type = "Function",
   13  
   14  			Returns =
   15  			{
   16  				{ Name = "totalFreeSlots", Type = "number", Nilable = false },
   17  			},
   18  		},
   19  		{
   20  			Name = "ContainerIDToInventoryID",
```

## PLAYER_SWING consumed by Blizzard's swing timer [P0.2 S8]

`<forever-src>/Interface/AddOns/Blizzard_SwingTimer/Blizzard_SwingTimer.lua` lines 60,66

```lua
   60  
   61  function SwingTimerMixin:OnEvent(event, ...)
   62  	if event == "PLAYER_SWING" then
   63  		local swingDuration, swingType = ...;
   64  		if self.swingType == swingType then
   65  			self:ResetSwingTimer(swingDuration);
   66  		end
```

## Plus/minus textures used by Forever's own UI [P2.2]

    Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Listing.lua:955:		button.ExpandOrCollapseButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
    Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Listing.lua:957:		button.ExpandOrCollapseButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up");
    Interface/AddOns/Blizzard_UIPanels_Game/Cata/QuestLogFrame.lua:240:					questLogTitle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
    Interface/AddOns/Blizzard_UIPanels_Game/Cata/QuestLogFrame.lua:242:					questLogTitle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up");
