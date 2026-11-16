# Reads wow.export Forever CSVs and writes the camelot-only WindTools data files.
# Default export folder: C:\Users\dack_janiels\wow.export\Forever
# Output is the ElvUI_WindTools repo next to this scripts repo.

param(
	[string]$ExportPath = "C:\Users\dack_janiels\wow.export\Forever"
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false

$addonRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\ElvUI_WindTools")
$enchantPath = Join-Path $addonRoot "Libraries\LibItemEnchant\LibItemEnchant_Forever.lua"
$consumablePath = Join-Path $addonRoot "Modules\Item\ExtraItemBar_Data_Forever.lua"

function Read-ExportCsv([string]$name) {
	$path = Join-Path $ExportPath $name
	if (-not (Test-Path $path)) {
		throw "Missing export CSV: $path"
	}
	return Import-Csv $path -Delimiter ';'
}

function Format-LuaName([string]$name) {
	if ([string]::IsNullOrWhiteSpace($name)) {
		return ""
	}
	return (($name -replace '[\r\n]+', ' ').Trim())
}

function Test-KeepName([string]$name) {
	if ([string]::IsNullOrWhiteSpace($name)) { return $false }
	if ($name -match '(?i)deprecated') { return $false }
	if ($name -match '(?i)\(TEST\)') { return $false }
	if ($name -match '(?i)^TEST\b') { return $false }
	if ($name -match '(?i)^OLD') { return $false }
	if ($name -match '(?i)^QA\b') { return $false }
	if ($name -match '^Ensemble:') { return $false }
	return $true
}

function Test-SecondaryName([string]$name) {
	if ([string]::IsNullOrWhiteSpace($name)) { return $true }
	if ($name -match '(?i)^formula:') { return $true }
	if ($name -match '(?i)deprecated') { return $true }
	if ($name -match '(?i)\(TEST\)') { return $true }
	if ($name -match '(?i)^TEST\b') { return $true }
	if ($name -match '(?i)^OLD') { return $true }
	if ($name -match '(?i)^QA\b') { return $true }
	return $false
}

function Format-EnchantLines($enchantId, $values, $names) {
	$lines = New-Object System.Collections.Generic.List[string]
	$sorted = @($values | Sort-Object -Unique)
	$primary = $sorted[0]
	foreach ($candidate in $sorted) {
		if (-not (Test-SecondaryName ([string]$names[$candidate]))) {
			$primary = $candidate
			break
		}
	}
	$lines.Add(("`t[{0}] = {1}, -- {2}" -f $enchantId, $primary, (Format-LuaName $names[$primary])))
	foreach ($extra in $sorted) {
		if ($extra -eq $primary) { continue }
		$lines.Add(("`t-- [{0}] = {1}, -- {2}" -f $enchantId, $extra, (Format-LuaName $names[$extra])))
	}
	return $lines
}

function Format-ItemList([string]$title, $ids, $names) {
	$builder = New-Object System.Text.StringBuilder
	[void]$builder.AppendLine("local $title = {")
	foreach ($itemId in ($ids | Sort-Object)) {
		[void]$builder.AppendLine(("`t{0}, -- {1}" -f $itemId, (Format-LuaName $names[$itemId])))
	}
	[void]$builder.AppendLine("}")
	[void]$builder.AppendLine()
	return $builder.ToString()
}

$enchantNames = @{}
foreach ($row in (Read-ExportCsv "SpellItemEnchantment.csv")) {
	$enchantNames[[int]$row.ID] = $row.Name_lang
}

$spellNames = @{}
foreach ($row in (Read-ExportCsv "SpellName.csv")) {
	$spellNames[[int]$row.ID] = $row.Name_lang
}

$itemNames = @{}
foreach ($row in (Read-ExportCsv "ItemSparse.csv")) {
	$itemNames[[int]$row.ID] = $row.Display_lang
}

# Effect 53 is a permanent enchant item. Effect 54 is a temporary enchant item.
$spellsByEnchant = @{}
foreach ($row in (Read-ExportCsv "SpellEffect.csv")) {
	if ($row.Effect -ne "53" -and $row.Effect -ne "54") { continue }
	$miscRaw = ($row.EffectMiscValue -split ',')[0]
	if ($miscRaw -notmatch '^\d+$') { continue }
	$enchantId = [int]$miscRaw
	if (-not $enchantNames.ContainsKey($enchantId)) { continue }
	$spellId = [int]$row.SpellID
	if (-not $spellsByEnchant.ContainsKey($enchantId)) {
		$spellsByEnchant[$enchantId] = New-Object System.Collections.Generic.List[int]
	}
	if (-not $spellsByEnchant[$enchantId].Contains($spellId)) {
		$spellsByEnchant[$enchantId].Add($spellId)
	}
}

$effectSpell = @{}
foreach ($row in (Read-ExportCsv "ItemEffect.csv")) {
	$effectSpell[[int]$row.ID] = [int]$row.SpellID
}

$itemsBySpell = @{}
foreach ($row in (Read-ExportCsv "ItemXItemEffect.csv")) {
	$effectId = [int]$row.ItemEffectID
	if (-not $effectSpell.ContainsKey($effectId)) { continue }
	$spellId = $effectSpell[$effectId]
	$itemId = [int]$row.ItemID
	if (-not $itemsBySpell.ContainsKey($spellId)) {
		$itemsBySpell[$spellId] = New-Object System.Collections.Generic.List[int]
	}
	if (-not $itemsBySpell[$spellId].Contains($itemId)) {
		$itemsBySpell[$spellId].Add($itemId)
	}
}

$itemsByEnchant = @{}
foreach ($pair in $spellsByEnchant.GetEnumerator()) {
	$itemIds = New-Object System.Collections.Generic.List[int]
	foreach ($spellId in $pair.Value) {
		if (-not $itemsBySpell.ContainsKey($spellId)) { continue }
		foreach ($itemId in $itemsBySpell[$spellId]) {
			if (-not $itemIds.Contains($itemId)) { $itemIds.Add($itemId) }
		}
	}
	if ($itemIds.Count -gt 0) {
		$itemsByEnchant[$pair.Key] = $itemIds
	}
}

$spellLines = Format-EnchantLines 13 $spellsByEnchant[13] $spellNames
$itemLines = Format-EnchantLines 13 $itemsByEnchant[13] $itemNames
if ($spellLines[0] -notmatch '\[13\] = 2829,') { throw "Enchant 13 did not keep spell 2829" }
if ($itemLines[0] -notmatch '\[13\] = 2863,') { throw "Enchant 13 did not keep item 2863" }

$enchantBuilder = New-Object System.Text.StringBuilder
[void]$enchantBuilder.AppendLine("--- Author: loudsoul (TinyInspect), Witness (NDui_Plus)")
[void]$enchantBuilder.AppendLine("--- Modifed for avoiding conflict with TinyInspect")
[void]$enchantBuilder.AppendLine('local MAJOR, MINOR = "LibItemEnchant-WT", 1')
[void]$enchantBuilder.AppendLine("local lib = LibStub:NewLibrary(MAJOR, MINOR) ---@class LibItemEnchantWT : table")
[void]$enchantBuilder.AppendLine()
[void]$enchantBuilder.AppendLine("if not lib then")
[void]$enchantBuilder.AppendLine("`treturn")
[void]$enchantBuilder.AppendLine("end")
[void]$enchantBuilder.AppendLine()
[void]$enchantBuilder.AppendLine("-- Generated from wow.export Forever CSVs")
[void]$enchantBuilder.AppendLine("local EnchantItemDB = {")
foreach ($enchantId in ($itemsByEnchant.Keys | Sort-Object)) {
	foreach ($line in (Format-EnchantLines $enchantId $itemsByEnchant[$enchantId] $itemNames)) {
		[void]$enchantBuilder.AppendLine($line)
	}
}
[void]$enchantBuilder.AppendLine("}")
[void]$enchantBuilder.AppendLine()
[void]$enchantBuilder.AppendLine("local EnchantSpellDB = {")
foreach ($enchantId in ($spellsByEnchant.Keys | Sort-Object)) {
	foreach ($line in (Format-EnchantLines $enchantId $spellsByEnchant[$enchantId] $spellNames)) {
		[void]$enchantBuilder.AppendLine($line)
	}
}
[void]$enchantBuilder.AppendLine("}")
[void]$enchantBuilder.AppendLine()
[void]$enchantBuilder.AppendLine("---Gets enchantment spell ID from item link")
[void]$enchantBuilder.AppendLine("---@param enchantID number Enchantment ID")
[void]$enchantBuilder.AppendLine("---@return number|nil enchantSpellID Enchantment spell ID, or nil if not found")
[void]$enchantBuilder.AppendLine("function lib:GetEnchantSpellID(enchantID)")
[void]$enchantBuilder.AppendLine("`treturn enchantID and EnchantSpellDB[enchantID]")
[void]$enchantBuilder.AppendLine("end")
[void]$enchantBuilder.AppendLine()
[void]$enchantBuilder.AppendLine("---Gets enchantment item ID from item link")
[void]$enchantBuilder.AppendLine("---@param enchantID number Enchantment ID")
[void]$enchantBuilder.AppendLine("---@return number|nil enchantItemID Enchantment item ID, or nil if not found")
[void]$enchantBuilder.AppendLine("function lib:GetEnchantItemID(enchantID)")
[void]$enchantBuilder.AppendLine("`treturn enchantID and EnchantItemDB[enchantID]")
[void]$enchantBuilder.AppendLine("end")
[System.IO.File]::WriteAllText($enchantPath, $enchantBuilder.ToString() + "`r`n", $utf8)

$itemClass = @{}
foreach ($row in (Read-ExportCsv "Item.csv")) {
	if ($row.ClassID -eq "0") {
		$itemClass[[int]$row.ID] = [int]$row.SubclassID
	}
}

$effectTrigger = @{}
foreach ($row in (Read-ExportCsv "ItemEffect.csv")) {
	$effectTrigger[[int]$row.ID] = $row.TriggerType
}

$grouped = @{
	1 = New-Object System.Collections.Generic.HashSet[int]
	2 = New-Object System.Collections.Generic.HashSet[int]
	3 = New-Object System.Collections.Generic.HashSet[int]
	4 = New-Object System.Collections.Generic.HashSet[int]
	5 = New-Object System.Collections.Generic.HashSet[int]
	7 = New-Object System.Collections.Generic.HashSet[int]
	utility = New-Object System.Collections.Generic.HashSet[int]
}
$utilitySubclasses = @{ 0 = $true; 8 = $true; 13 = $true; 14 = $true; 15 = $true }
foreach ($row in (Read-ExportCsv "ItemXItemEffect.csv")) {
	$itemId = [int]$row.ItemID
	if (-not $itemClass.ContainsKey($itemId)) { continue }
	$effectId = [int]$row.ItemEffectID
	if (-not $effectTrigger.ContainsKey($effectId) -or $effectTrigger[$effectId] -ne "0") { continue }
	if (-not (Test-KeepName $itemNames[$itemId])) { continue }
	$subclassId = $itemClass[$itemId]
	if ($grouped.ContainsKey($subclassId)) {
		[void]$grouped[$subclassId].Add($itemId)
	}
	elseif ($utilitySubclasses.ContainsKey($subclassId)) {
		[void]$grouped["utility"].Add($itemId)
	}
}

$consumableBuilder = New-Object System.Text.StringBuilder
[void]$consumableBuilder.AppendLine("local W = unpack((select(2, ...))) ---@type WindTools")
[void]$consumableBuilder.AppendLine('local EB = W:GetModule("ExtraItemsBar") ---@class ExtraItemsBar')
[void]$consumableBuilder.AppendLine()
[void]$consumableBuilder.AppendLine("-- Generated from wow.export Forever CSVs")
[void]$consumableBuilder.Append((Format-ItemList "foreverPotions" $grouped[1] $itemNames))
[void]$consumableBuilder.Append((Format-ItemList "foreverElixirs" $grouped[2] $itemNames))
[void]$consumableBuilder.Append((Format-ItemList "foreverFlasks" $grouped[3] $itemNames))
[void]$consumableBuilder.Append((Format-ItemList "foreverScrolls" $grouped[4] $itemNames))
[void]$consumableBuilder.Append((Format-ItemList "foreverFoods" $grouped[5] $itemNames))
[void]$consumableBuilder.Append((Format-ItemList "foreverBandages" $grouped[7] $itemNames))
[void]$consumableBuilder.Append((Format-ItemList "foreverUtilities" $grouped["utility"] $itemNames))
[void]$consumableBuilder.AppendLine("EB.StateCheckList = {}")
[void]$consumableBuilder.AppendLine("EB.CountThreshold = {}")
[void]$consumableBuilder.AppendLine("EB.ModuleList = {")
[void]$consumableBuilder.AppendLine("`tPOTIONFOREVER = foreverPotions,")
[void]$consumableBuilder.AppendLine("`tELIXIRFOREVER = foreverElixirs,")
[void]$consumableBuilder.AppendLine("`tFLASKFOREVER = foreverFlasks,")
[void]$consumableBuilder.AppendLine("`tSCROLLFOREVER = foreverScrolls,")
[void]$consumableBuilder.AppendLine("`tFOODFOREVER = foreverFoods,")
[void]$consumableBuilder.AppendLine("`tBANDAGEFOREVER = foreverBandages,")
[void]$consumableBuilder.AppendLine("`tUTILITYFOREVER = foreverUtilities,")
[void]$consumableBuilder.AppendLine("}")
[System.IO.File]::WriteAllText($consumablePath, $consumableBuilder.ToString() + "`r`n", $utf8)

Write-Output ("enchants with spells " + $spellsByEnchant.Count)
Write-Output ("enchants with items " + $itemsByEnchant.Count)
Write-Output ("potions " + $grouped[1].Count)
Write-Output ("elixirs " + $grouped[2].Count)
Write-Output ("flasks " + $grouped[3].Count)
Write-Output ("scrolls " + $grouped[4].Count)
Write-Output ("food " + $grouped[5].Count)
Write-Output ("bandages " + $grouped[7].Count)
Write-Output ("utility " + $grouped["utility"].Count)
Write-Output $enchantPath
Write-Output $consumablePath
