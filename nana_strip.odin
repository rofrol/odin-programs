package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

PREFIX :: "NANA"

when PREFIX == "" {
	#panic("PREFIX must not be empty")
}

Options :: struct {
	n:   bool `usage:"dry-run — preview changes without renaming anything"`,
	dir: string `args:"pos=0,required" usage:"directory to strip prefixes in"`,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)

	d, open_err := os.open(opt.dir)
	if open_err != nil {
		fmt.eprintf("Cannot open directory '%s': %v\n", opt.dir, open_err)
		os.exit(1)
	}
	defer os.close(d)

	entries, read_err := os.read_dir(d, -1, context.allocator)
	if read_err != nil {
		fmt.eprintf("Cannot read directory '%s': %v\n", opt.dir, read_err)
		os.exit(1)
	}
	defer os.file_info_slice_delete(entries, context.allocator)

	if opt.n {
		fmt.println("[DRY RUN — no files will be renamed]\n")
	}

	renamed, skipped := 0, 0

	for entry in entries {
		defer free_all(context.temp_allocator)

		if entry.type == .Directory do continue

		new_name := strings.trim_prefix(entry.name, PREFIX)
		if new_name == entry.name {
			fmt.printf("Skipped: '%s' (no prefix)\n", entry.name)
			skipped += 1
			continue
		}
		if new_name == "" {
			fmt.eprintf("Skipped '%s': name would be empty after stripping\n", entry.name)
			skipped += 1
			continue
		}

		if opt.n {
			fmt.printf("  '%s'  →  '%s'\n", entry.name, new_name)
			renamed += 1
			continue
		}

		old_path, _ := filepath.join({opt.dir, entry.name}, context.temp_allocator)
		new_path, _ := filepath.join({opt.dir, new_name}, context.temp_allocator)

		if err := os.rename(old_path, new_path); err != nil {
			fmt.eprintf("Error renaming '%s' → '%s': %v\n", entry.name, new_name, err)
			skipped += 1
		} else {
			fmt.printf("OK  '%s'  →  '%s'\n", entry.name, new_name)
			renamed += 1
		}
	}

	fmt.println()
	if opt.n {
		fmt.printf("Dry run: %d file(s) would be renamed", renamed)
	} else {
		fmt.printf("Done — renamed %d file(s)", renamed)
	}
	if skipped > 0 {
		fmt.printf(", skipped %d", skipped)
	}
	fmt.println(".")
}

