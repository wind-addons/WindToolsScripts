package main

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"sort"
	"strconv"
)

type configFile struct {
	Config config `json:"config"`
}

type config struct {
	WorldMapOverlay     string `json:"world_map_overlay"`
	WorldMapOverlayTile string `json:"world_map_overlay_tile"`
	Output              string `json:"output"`
	OutputStyle         string `json:"output_style"`
}

type overlay struct {
	ID            int
	UIMapArtID    int
	TextureWidth  int
	TextureHeight int
	OffsetX       int
	OffsetY       int
}

type overlayTile struct {
	ID                int
	RowIndex          int
	ColIndex          int
	LayerIndex        int
	FileDataID        int
	WorldMapOverlayID int
}

func main() {
	configPath := "config.json"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}

	config := loadConfig(configPath)

	overlays := loadOverlay(config.WorldMapOverlay)
	overlayTiles := loadOverlayTiles(config.WorldMapOverlayTile)

	sort.Slice(overlayTiles, func(left, right int) bool {
		if overlayTiles[left].WorldMapOverlayID != overlayTiles[right].WorldMapOverlayID {
			return overlayTiles[left].WorldMapOverlayID < overlayTiles[right].WorldMapOverlayID
		}
		if overlayTiles[left].RowIndex != overlayTiles[right].RowIndex {
			return overlayTiles[left].RowIndex < overlayTiles[right].RowIndex
		}
		if overlayTiles[left].ColIndex != overlayTiles[right].ColIndex {
			return overlayTiles[left].ColIndex < overlayTiles[right].ColIndex
		}
		if overlayTiles[left].LayerIndex != overlayTiles[right].LayerIndex {
			return overlayTiles[left].LayerIndex < overlayTiles[right].LayerIndex
		}
		return overlayTiles[left].ID < overlayTiles[right].ID
	})

	mapTexture := make(map[int]map[string][]int)

	for _, overlayTile := range overlayTiles {
		overlayRecord, found := overlays[overlayTile.WorldMapOverlayID]
		if !found {
			continue
		}
		if overlayRecord.TextureWidth == 0 || overlayRecord.TextureHeight == 0 {
			continue
		}

		textureInfo := fmt.Sprintf("%d:%d:%d:%d",
			overlayRecord.TextureWidth,
			overlayRecord.TextureHeight,
			overlayRecord.OffsetX,
			overlayRecord.OffsetY)

		thisMap := mapTexture[overlayRecord.UIMapArtID]

		if thisMap == nil {
			thisMap = make(map[string][]int)
		}

		if thisMap[textureInfo] == nil {
			thisMap[textureInfo] = []int{overlayTile.FileDataID}
		} else {
			alreadyExist := false
			for _, dataID := range thisMap[textureInfo] {
				if dataID == overlayTile.FileDataID {
					alreadyExist = true
				}
			}

			if alreadyExist == false {
				thisMap[textureInfo] = append(thisMap[textureInfo], overlayTile.FileDataID)
			}
		}

		mapTexture[overlayRecord.UIMapArtID] = thisMap
	}

	exportData(config.Output, config.OutputStyle, mapTexture)
}

func toInt(text string) int {
	number, err := strconv.Atoi(text)
	if err != nil {
		log.Fatalln("The text cannot be converted to int", err)
	}
	return number
}

func loadConfig(filePath string) config {
	jsonFile, err := os.Open(filePath)
	if err != nil {
		log.Fatalln("Couldn't open the config file", err)
	}
	defer jsonFile.Close()

	byteValue, err := io.ReadAll(jsonFile)
	if err != nil {
		log.Fatalln("Cannot read config", err)
	}

	var configFile configFile
	err = json.Unmarshal(byteValue, &configFile)
	if err != nil {
		log.Fatalln("Cannot parse config", err)
	}

	return configFile.Config
}

func openTable(filePath string) *csv.Reader {
	fileContents, err := os.ReadFile(filePath)
	if err != nil {
		log.Fatalln("Couldn't open the csv file", err)
	}

	headerLine := fileContents
	if newlineIndex := bytes.IndexByte(fileContents, '\n'); newlineIndex >= 0 {
		headerLine = fileContents[:newlineIndex]
	}

	tableReader := csv.NewReader(bytes.NewReader(fileContents))
	tableReader.FieldsPerRecord = -1
	if bytes.Contains(headerLine, []byte(";")) {
		tableReader.Comma = ';'
	}

	return tableReader
}

func loadOverlay(filePath string) map[int]overlay {
	csvReader := openTable(filePath)

	overlays := make(map[int]overlay)

	// Skip the first line
	_, err := csvReader.Read()
	if err != nil {
		log.Fatalf("can not read, err is %+v", err)
	}

	for {
		row, err := csvReader.Read()
		if err != nil && err != io.EOF {
			log.Fatalf("can not read, err is %+v", err)
		}
		if err == io.EOF {
			break
		}
		if len(row) < 6 {
			log.Fatalf("overlay row has %d columns, need art id and texture rect", len(row))
		}

		overlays[toInt(row[0])] = overlay{
			ID:            toInt(row[0]),
			UIMapArtID:    toInt(row[1]),
			TextureWidth:  toInt(row[2]),
			TextureHeight: toInt(row[3]),
			OffsetX:       toInt(row[4]),
			OffsetY:       toInt(row[5]),
		}
	}

	return overlays
}

func loadOverlayTiles(filePath string) []overlayTile {
	csvReader := openTable(filePath)

	var overlayTiles []overlayTile

	// Skip the first line
	_, err := csvReader.Read()
	if err != nil {
		log.Fatalf("can not read, err is %+v", err)
	}

	for {
		row, err := csvReader.Read()
		if err != nil && err != io.EOF {
			log.Fatalf("can not read, err is %+v", err)
		}
		if err == io.EOF {
			break
		}
		if len(row) < 6 {
			log.Fatalf("overlay tile row has %d columns, need file id and overlay id", len(row))
		}

		overlayTiles = append(overlayTiles, overlayTile{
			ID:                toInt(row[0]),
			RowIndex:          toInt(row[1]),
			ColIndex:          toInt(row[2]),
			LayerIndex:        toInt(row[3]),
			FileDataID:        toInt(row[4]),
			WorldMapOverlayID: toInt(row[5]),
		})
	}

	return overlayTiles
}

func exportData(filePath string, outputStyle string, data map[int]map[string][]int) {
	file, err := os.OpenFile(filePath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0666)
	if err != nil {
		log.Fatalln("Couldn't open the result file.", err)
	}
	defer file.Close()

	var idList []int
	for id := range data {
		idList = append(idList, id)
	}
	sort.Ints(idList)

	if outputStyle == "forever" || outputStyle == "retail" {
		fmt.Fprintln(file, "local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable")
		if outputStyle == "forever" {
			fmt.Fprintln(file, "if not E.Forever then return end")
		} else {
			fmt.Fprintln(file, "if E.Forever then return end")
		}
		fmt.Fprintln(file, "W.WorldMapRevealDatabase = {")
	} else if outputStyle == "" {
		fmt.Fprintln(file, "local RevealDatabase = {")
	} else {
		log.Fatalln("Unknown output_style", outputStyle)
	}

	for _, id := range idList {
		fmt.Fprintln(file, "    ["+strconv.Itoa(id)+"] = {")

		var mapInfoList []string
		for mapInfo := range data[id] {
			mapInfoList = append(mapInfoList, mapInfo)
		}
		sort.Strings(mapInfoList)

		for _, mapInfo := range mapInfoList {
			fmt.Fprintf(file, "        [\"%s\"] = \"", mapInfo)
			for index, dataID := range data[id][mapInfo] {
				if index == 0 {
					fmt.Fprintf(file, "%d", dataID)
				} else {
					fmt.Fprintf(file, ", %d", dataID)
				}
			}
			fmt.Fprintf(file, "\",\n")
		}

		fmt.Fprintln(file, "    },")
	}

	fmt.Fprintln(file, "}")
}
