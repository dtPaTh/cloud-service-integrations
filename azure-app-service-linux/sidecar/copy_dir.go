package main

import (
    "fmt"
    "io"
    "os"
    "path/filepath"
)

func copyDir(src, dst string) error {
    return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
        if err != nil {
            return err
        }
        relPath, _ := filepath.Rel(src, path)
        destPath := filepath.Join(dst, relPath)

        if info.IsDir() {
            return os.MkdirAll(destPath, info.Mode())
        }

        srcFile, err := os.Open(path)
        if err != nil {
            return err
        }
        defer srcFile.Close()

        destFile, err := os.Create(destPath)
        if err != nil {
            return err
        }
        defer destFile.Close()

        _, err = io.Copy(destFile, srcFile)
        return err
    })
}

func main() {
    if len(os.Args) != 3 {
        fmt.Println("Usage: copy_directory <source_directory> <target_directory>")
        return
    }

    sourceDir := os.Args[1]
    destinationDir := os.Args[2]

    err := copyDir(sourceDir, destinationDir)
    if err != nil {
        fmt.Println("Error:", err)
    } else {
        fmt.Println("Directory copied successfully!")
    }
}
