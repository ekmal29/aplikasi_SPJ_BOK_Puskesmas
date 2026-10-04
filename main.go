package main

import (
	"embed"
	"io/fs"
	"log"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

var AppVersion = "3.5"

//go:embed all:templates
var assets embed.FS

func main() {
	// Arahkan Wails agar membaca folder 'templates' sebagai root frontend
	tmplFS, _ := fs.Sub(assets, "templates")

	// Inisialisasi struct App (berisi logika backend & SQLite kita)
	app := NewApp()

	// Konfigurasi dan jalankan Wails Desktop
	err := wails.Run(&options.App{
		Title:            "Generator SPJ",
		Width:            1024,
		Height:           768,
		WindowStartState: options.Maximised,
		AssetServer: &assetserver.Options{
			Assets: tmplFS,
		},
		OnStartup:     app.startup,
		OnBeforeClose: app.beforeClose,
		Bind: []interface{}{
			app, // Daftarkan struct app agar fungsinya bisa diakses dari Javascript HTML
		},
	})

	if err != nil {
		log.Fatal("Wails error:", err)
	}
}
