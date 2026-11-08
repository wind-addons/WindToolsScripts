# WindTools Scripts

Here are some scripts used in development of ElvUI_WindTools.

## CheckGlobals

Analyse the global variables using. (Based on FindGlobals.)

## MergeLocales

Update the localization strings that managed by AceLocale-3.0.

## MapOverlay

Builds the fog-of-war texture list used by ElvUI_WindTools world map reveal.

Export `WorldMapOverlay` and `WorldMapOverlayTile` from the client (wow.export writes semicolon-separated CSV). The older comma-separated dump from [wow.tools](https://wow.tools/) still works. The reader uses `;` when the header contains it, and it only needs the art id, texture size, offsets, tile row, tile column, file id, and overlay id. Rows with a texture width or height of 0 are skipped.

Put each client’s pair of CSV files in its own folder:

- `MapOverlay/retail/WorldMapOverlay.csv` and `WorldMapOverlayTile.csv`
- `MapOverlay/forever/WorldMapOverlay.csv` and `WorldMapOverlayTile.csv`

`config.retail.json` and `config.forever.json` write the addon files. Those output paths are relative to `MapOverlay`, and they expect `ElvUI_WindTools` to sit next to this repo. Run the commands from `MapOverlay`. Go 1.21 or newer is required (`go.mod` is in this folder).

```powershell
go run . config.retail.json
go run . config.forever.json
```

Retail writes `ElvUI_WindTools/Modules/Maps/WorldMapReveal_Retail.lua`. That file returns immediately on WoW Forever. Forever writes `WorldMapReveal_Forever.lua`, which returns immediately on retail. `WorldMap.lua` reads `W.WorldMapRevealDatabase` from whichever file ran.

`output_style` in the config picks the header:

- `retail` sets the table only when `E.Forever` is false
- `forever` sets the table only when `E.Forever` is true
- omit it to write a plain `local RevealDatabase = { ... }` table

`go run .` with no argument uses `config.json`, reads `worldmapoverlay.csv` and `worldmapoverlaytile.csv` in this folder, and writes that plain table to `data.lua`. `build.bat` builds `GetMapOverlay.exe`, which takes the same optional config path (`GetMapOverlay.exe config.retail.json`).