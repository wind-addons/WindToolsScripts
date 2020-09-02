package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type configFile struct {
	Config config `json:"config"`
}

type config struct {
	FolderPath string   `json:"folder"`
	Exclude    []string `json:"exclude"`
	Output     string   `json:"output"`
}

func main() {
	config := loadConfig("config.json")

	absoluteFolderPath, err := filepath.Abs(config.FolderPath)
	if err != nil {
		log.Fatalln("Couldn't get the absolute path of folder", err)
	}

	luaFiles := getLuaFiles(absoluteFolderPath)

	file, err := os.OpenFile(config.Output, os.O_CREATE|os.O_TRUNC, 0666)
	if err != nil {
		log.Fatalln("Couldn't open the result file.", err)
	}
	defer file.Close()

	for _, luaFile := range luaFiles {
		isExclude := false

		if len(config.Exclude) > 0 {
			for _, excludeString := range config.Exclude {
				if strings.Contains(luaFile, excludeString) {
					isExclude = true
				}
			}
		}

		if isExclude {
			continue
		}

		args := "lua\\luac.exe -l -p %LUAFILE% | lua\\lua.exe globals.lua %LUAFILE%"
		cmd := exec.Command("cmd", "/c", args)
		cmd.Env = append(os.Environ(),
			fmt.Sprintf(`LUAFILE="%s"`, luaFile),
		)

		out, _ := cmd.CombinedOutput()

		output := string(out)
		if len(output) > 2 {
			fmt.Fprintln(file, output)
		}
	}
}

func getLuaFiles(folder string) []string {
	var files []string

	err := filepath.Walk(folder, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && path[len(path)-3:] == "lua" {
			files = append(files, path)
		}

		return nil
	})

	if err != nil {
		log.Fatalln("Walk error", err)
	}

	return files
}

func loadConfig(filePath string) config {
	jsonFile, err := os.OpenFile(filePath, os.O_RDONLY, 0444)
	if err != nil {
		log.Fatalln("Couldn't open the csv file", err)
	}
	defer jsonFile.Close()

	byteValue, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		log.Fatalln("Cannot read config", err)
	}

	var configFile configFile
	json.Unmarshal([]byte(byteValue), &configFile)

	return configFile.Config
}
