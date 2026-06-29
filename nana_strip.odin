package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

PREFIX :: "NANA"

usage :: proc() {
	fmt.eprintln("Usage: nana_strip [-n] <directory>")
	fmt.eprintln("  -n   dry-run — preview changes without renaming anything")
}

main :: proc() {
	if PREFIX == "" {
		fmt.eprintln("Error: PREFIX empty")
		os.exit(1)
	}

	args := os.args[1:]

	if len(args) == 0 {
		usage()
		os.exit(1)
	}

	dry_run := false
	dir_path := ""

	if args[0] == "-n" {
		if len(args) < 2 {
			fmt.eprintln("Error: missing directory path after -n flag")
			usage()
			os.exit(1)
		}
		dry_run = true
		dir_path = args[1]
	} else {
		dir_path = args[0]
	}

	d, open_err := os.open(dir_path)
	if open_err != nil {
		fmt.eprintf("Cannot open directory '%s': %v\n", dir_path, open_err)
		os.exit(1)
	}
	defer os.close(d)

	entries, read_err := os.read_dir(d, -1, context.allocator)
	if read_err != nil {
		fmt.eprintf("Cannot read directory '%s': %v\n", dir_path, read_err)
		os.exit(1)
	}
	defer os.file_info_slice_delete(entries, context.allocator)

	if dry_run {
		fmt.println("[DRY RUN — no files will be renamed]\n")
	}

	renamed, skipped := 0, 0

	context.allocator = context.temp_allocator
	for entry in entries {
		if entry.type == .Directory do continue

		if entry.name == PREFIX {
			fmt.eprintf("Skipped '%s': name would be empty after removing prefix\n", entry.name)
			skipped += 1
			continue
		}

		new_name := strings.trim_prefix(entry.name, PREFIX)
		// there was no prefix in file name, so continue
		if new_name == entry.name {
			fmt.printf("Skipped: '%s' → '%s'\n", entry.name, new_name)
			skipped += 1
			continue
		}

		if dry_run {
			fmt.printf("  '%s'  →  '%s'\n", entry.name, new_name)
			renamed += 1
			continue
		}

		old_path, _ := filepath.join({dir_path, entry.name})
		new_path, _ := filepath.join({dir_path, new_name})

		if err := os.rename(old_path, new_path); err != nil {
			fmt.eprintf("Error: '%s' → '%s': %v\n", entry.name, new_name, err)
			skipped += 1
		} else {
			fmt.printf("OK  '%s'  →  '%s'\n", entry.name, new_name)
			renamed += 1
		}

		free_all(context.temp_allocator)
	}

	fmt.println()
	if dry_run {
		fmt.printf("Dry run: %d file(s) would be renamed", renamed)
	} else {
		fmt.printf("Done — renamed %d file(s)", renamed)
	}
	if skipped > 0 {
		fmt.printf(", skipped %d", skipped)
	}
	fmt.println(".")
}

