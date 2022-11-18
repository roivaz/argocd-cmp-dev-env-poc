package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/urfave/cli/v2"
)

func main() {
	app := &cli.App{
		Name: "glbc-plugin",
		Commands: []*cli.Command{
			{
				Name:  "generate",
				Usage: "glbc-plugin generate <path>",
				Action: func(cCtx *cli.Context) error {
					path := cCtx.Args().First()
					// fmt.Printf("len(path)=%d", len(path))
					if len(path) < 1 {
						return cli.Exit("Must specify a path", 1)
					}
					// fmt.Printf("path: %s", path)

					// TODO: Sanity check path is not trying to break outside current dir
					err := filepath.Walk(path,
						func(file string, info os.FileInfo, err error) error {
							if err != nil {
								return err
							}
							// fmt.Println(file, info.Size())
							fileExtension := filepath.Ext(file)
							if fileExtension == ".yaml" {
								dat, err := os.ReadFile(file)
								if err != nil {
									log.Fatal(err)
								}
								fmt.Println("---")
								fmt.Println(string(dat))
							}
							return nil
						})
					if err != nil {
						log.Fatal(err)
					}
					return nil
				},
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
