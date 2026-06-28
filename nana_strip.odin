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
	args := os.args[1:]

	if len(args) == 0 {
		usage()
		os.exit(1)
	}

	dry_run := false
	dir_path := ""

	switch {
	case args[0] == "-n":
		if len(args) < 2 {
			fmt.eprintln("Error: missing directory path after -n flag")
			usage()
			os.exit(1)
		}
		dry_run = true
		dir_path = args[1]
	case:
		dir_path = args[0]
	}

	d, open_err := os.open(dir_path)
	if open_err != os.ERROR_NONE {
		fmt.eprintf("Cannot open directory '%s': %v\n", dir_path, open_err)
		os.exit(1)
	}
	defer os.close(d)

	// fix 1 + fix 2: read_dir and file_info_slice_delete require an explicit allocator
	entries, read_err := os.read_dir(d, -1, context.allocator)
	if read_err != os.ERROR_NONE {
		fmt.eprintf("Cannot read directory '%s': %v\n", dir_path, read_err)
		os.exit(1)
	}
	defer os.file_info_slice_delete(entries, context.allocator)

	if dry_run {
		fmt.println("[DRY RUN — no files will be renamed]\n")
	}

	renamed, skipped := 0, 0

	for entry in entries {
		// File_Info has no is_dir — the new os API exposes File_Type enum instead
		if entry.type == .Directory do continue

		name := entry.name
		if !strings.has_prefix(name, PREFIX) do continue

		new_name := name[len(PREFIX):]
		if len(new_name) == 0 {
			fmt.eprintf("Skipped '%s': name would be empty after stripping prefix\n", name)
			skipped += 1
			continue
		}

		if dry_run {
			fmt.printf("  '%s'  →  '%s'\n", name, new_name)
			renamed += 1
			continue
		}

		// fix 4: filepath.join returns (string, Allocator_Error)
		old_path, _ := filepath.join({dir_path, name})
		new_path, _ := filepath.join({dir_path, new_name})

		if err := os.rename(old_path, new_path); err != os.ERROR_NONE {
			fmt.eprintf("Error: '%s' → '%s': %v\n", name, new_name, err)
			skipped += 1
		} else {
			fmt.printf("OK  '%s'  →  '%s'\n", name, new_name)
			renamed += 1
		}

		delete(old_path)
		delete(new_path)
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

