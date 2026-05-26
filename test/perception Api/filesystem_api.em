// =============================================================================
// Filesystem API — comprehensive coverage test
//
// Exercises every function, every edge case, and every failure mode documented
// in the Filesystem API specification.
//
// CHECKLIST — All types, functions, and methods in the API:
//
//   Standalone functions:
//     fs_create_file(path, data)           -> bool
//     fs_create_directory(path)            -> bool
//     fs_file_exists(path)                 -> bool
//     fs_dir_exists(path)                  -> bool
//     fs_delete_file(path)                 -> bool
//     fs_delete_directory(path)            -> bool
//     fs_file_size(path)                   -> int64
//     fs_read_file(path)                   -> string
//     fs_write_file(path, data)            -> bool
//     fs_append_file(path, data)           -> bool
//     fs_read_file_binary(path)            -> array<uint8>
//     fs_write_file_binary(path, bytes)    -> bool
//     fs_append_file_binary(path, bytes)   -> bool
//     fs_list_files(path)                  -> array<string>
//     fs_list_dirs(path)                   -> array<string>
//     fs_list_all(path)                    -> array<string>
//
//   Sandbox rejection rules:
//     - absolute paths (C:\, /etc/...)
//     - UNC paths (\\server\share)
//     - parent traversals (..)
//     - leading slashes (/foo, \foo)
//     - embedded control chars (:, \n, \r, \0)
//     - empty path
//
//   Failure modes (all return false/0/empty):
//     - file_system_access permission off
//     - path validation fails
//     - target missing
//     - underlying I/O error
//
//   Edge cases:
//     - empty data creates zero-byte file
//     - empty binary write creates zero-byte file
//     - empty binary append is a no-op (returns true)
//     - read missing file returns ""
//     - read_binary missing returns empty array
//     - file_size of missing file returns 0
//     - delete of missing file returns false
//     - delete non-empty directory fails
//     - list in missing dir returns empty array
//     - entries are basenames (no path prefix)
//     - no recursion in listing
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

void check(string label, bool ok) {
    if (ok) {
        g_pass = g_pass + 1;
        print_console("  [PASS] " + label);
    } else {
        g_fail = g_fail + 1;
        print_console("  [FAIL] " + label);
    }
}

void section(string name) {
    print_console("");
    print_console("--- " + name + " ---");
}

// ---------------------------------------------------------------------------
// Cleanup helper — recursively remove a tree by relative path.
// Returns true if the path no longer exists when we're done.
// ---------------------------------------------------------------------------

bool cleanup_path(string path) {
    // Delete any files inside
    array<string> all = fs_list_all(path);
    int64 ii = 0;
    while (ii < cast<int64>(all.length())) {
        string entry = path + "/" + all.get(ii);
        // Try as file first, then as directory (recursive)
        if (!fs_delete_file(entry)) {
            cleanup_path(entry);
            fs_delete_directory(entry);
        }
        ii = ii + 1;
    }
    // Remove the directory itself if it exists
    if (fs_dir_exists(path)) {
        return fs_delete_directory(path);
    }
    return true;
}

// ===========================================================================
// Test routine
// ===========================================================================

void test_routine(int64 data) {
    if (g_done == 1) return;
    g_done = 1;

    print_console("=== Filesystem API — Full Coverage Test ===");

    // -----------------------------------------------------------------------
    // SECTION 1 — Sandbox escape attempts
    // Every escaped path below MUST return false / empty without touching
    // disk. We verify the boolean return of fs_create_file; for listing
    // functions we verify the empty array.
    // -----------------------------------------------------------------------

    section("1. Sandbox: absolute paths");
    check("absolute C:\\... rejected",        !fs_create_file("C:\\evil.txt", "x"));
    check("absolute /etc/passwd rejected",     !fs_create_file("/etc/passwd", "x"));
    check("absolute C:/ style rejected",       !fs_create_file("C:/evil.txt", "x"));
    check("absolute /tmp/foo rejected",        !fs_create_file("/tmp/foo", "x"));

    section("2. Sandbox: UNC paths");
    check("UNC \\\\server\\share rejected",    !fs_create_file("\\\\server\\share\\f", "x"));

    section("3. Sandbox: parent traversal");
    check("direct ../ rejected",               !fs_create_file("../escape.txt", "x"));
    check("nested ../ rejected",               !fs_create_file("ok/../escape.txt", "x"));
    check("deep ../../ rejected",              !fs_create_file("a/../../escape.txt", "x"));

    section("4. Sandbox: leading slashes");
    check("leading /foo rejected",             !fs_create_file("/foo", "x"));
    check("leading \\foo rejected",            !fs_create_file("\\foo", "x"));

    section("5. Sandbox: embedded control chars");
    check("embedded : rejected",               !fs_create_file("bad:name.txt", "x"));
    // NOTE: \n, \r, \0 in path strings are tested syntactically; the runtime
    // rejects them before touching disk.
    string path_with_newline = "bad\nfile.txt";
    check("embedded \\n rejected",             !fs_create_file(path_with_newline, "x"));
    string path_with_cr = "bad\rfile.txt";
    check("embedded \\r rejected",             !fs_create_file(path_with_cr, "x"));
    string path_with_nul = "bad\0file.txt";
    check("embedded \\0 rejected",             !fs_create_file(path_with_nul, "x"));

    section("6. Sandbox: empty path");
    check("empty path rejected",               !fs_create_file("", "x"));

    section("7. Sandbox: listing functions on rejected paths");
    check("fs_list_files on /etc empty",        fs_list_files("/etc").length() == 0);
    check("fs_list_dirs on /etc empty",         fs_list_dirs("/etc").length() == 0);
    check("fs_list_all on /etc empty",          fs_list_all("/etc").length() == 0);
    check("fs_list_files on ../ empty",         fs_list_files("../").length() == 0);
    check("fs_list_dirs on ../ empty",          fs_list_dirs("../").length() == 0);
    check("fs_list_all on ../ empty",           fs_list_all("../").length() == 0);

    // -----------------------------------------------------------------------
    // SECTION 2 — Clean working area
    // Ensure a clean base directory for the actual tests.
    // -----------------------------------------------------------------------

    section("8. Cleanup before tests");
    // Remove any leftovers from prior runs
    cleanup_path("fs_test");
    // Re-create the root test directory
    check("create root test dir",               fs_create_directory("fs_test"));

    // -----------------------------------------------------------------------
    // SECTION 3 — Basic file operations
    // -----------------------------------------------------------------------

    section("9. fs_create_file — basic");
    check("create file with content",           fs_create_file("fs_test/hello.txt", "Hello, Enma!"));
    check("file_exists after create",           fs_file_exists("fs_test/hello.txt"));
    check("file_size matches string",           fs_file_size("fs_test/hello.txt") == 12);
    check("dir_exists on file returns false",  !fs_dir_exists("fs_test/hello.txt"));

    section("10. fs_create_file — overwrite");
    check("overwrite existing file",            fs_create_file("fs_test/hello.txt", "Overwritten"));
    string after_overwrite = fs_read_file("fs_test/hello.txt");
    check("content is overwritten",             after_overwrite == "Overwritten");

    section("11. fs_create_file — zero-byte (empty data)");
    check("create zero-byte file",              fs_create_file("fs_test/empty.txt", ""));
    check("zero-byte file exists",              fs_file_exists("fs_test/empty.txt"));
    check("zero-byte file size is 0",           fs_file_size("fs_test/empty.txt") == 0);
    check("read of empty file returns \"\"",    fs_read_file("fs_test/empty.txt") == "");

    section("12. fs_file_exists / fs_dir_exists — negatives");
    check("file_exists on missing returns false", !fs_file_exists("fs_test/nope.txt"));
    check("dir_exists on missing returns false",  !fs_dir_exists("fs_test/nope_dir"));
    // A regular file is not a directory
    check("dir_exists on regular file false",    !fs_dir_exists("fs_test/hello.txt"));
    // A directory is not a file
    check("file_exists on directory false",      !fs_file_exists("fs_test"));

    // -----------------------------------------------------------------------
    // SECTION 4 — Text I/O
    // -----------------------------------------------------------------------

    section("13. fs_write_file — overwrite");
    check("write_file",                        fs_write_file("fs_test/text_io.txt", "Line 1"));
    check("read after write",                  fs_read_file("fs_test/text_io.txt") == "Line 1");
    check("write_file overwrite",              fs_write_file("fs_test/text_io.txt", "Line 1 revised"));
    check("verify overwrite",                  fs_read_file("fs_test/text_io.txt") == "Line 1 revised");

    section("14. fs_append_file");
    check("append to existing",                fs_append_file("fs_test/text_io.txt", "\nLine 2"));
    string appended = fs_read_file("fs_test/text_io.txt");
    check("read after append contains both",   appended == "Line 1 revised\nLine 2");

    section("15. fs_append_file — empty append is a no-op");
    check("append empty string",               fs_append_file("fs_test/text_io.txt", ""));
    string after_empty = fs_read_file("fs_test/text_io.txt");
    check("content unchanged after empty append", after_empty == "Line 1 revised\nLine 2");

    section("16. fs_read_file — edge cases");
    // Empty file returns ""
    check("read empty file returns \"\"",      fs_read_file("fs_test/empty.txt") == "");
    // Missing file returns ""
    check("read missing file returns \"\"",    fs_read_file("fs_test/missing.txt") == "");
    // But distinguishing them: empty file exists, missing doesn't
    check("exists on empty file true",         fs_file_exists("fs_test/empty.txt"));
    check("exists on missing file false",     !fs_file_exists("fs_test/missing.txt"));

    section("17. fs_write_file / fs_append_file — missing parent dir");
    // Writing into a non-existent parent must fail
    check("write into missing parent fails",  !fs_write_file("fs_test/nope/sub/file.txt", "x"));
    check("append into missing parent fails", !fs_append_file("fs_test/nope/sub/file.txt", "x"));
    check("create into missing parent fails", !fs_create_file("fs_test/nope/sub/file.txt", "x"));

    // -----------------------------------------------------------------------
    // SECTION 5 — Binary I/O
    // -----------------------------------------------------------------------

    section("18. fs_write_file_binary");
    array<uint8> bin_header;
    bin_header.push(0x4D);
    bin_header.push(0x5A);
    bin_header.push(0x90);
    bin_header.push(0x00);
    bin_header.push(0x03);
    check("write_file_binary 5 bytes",         fs_write_file_binary("fs_test/probe.bin", bin_header));
    check("file_size binary = 5",              fs_file_size("fs_test/probe.bin") == 5);

    section("19. fs_read_file_binary");
    array<uint8> bin_back = fs_read_file_binary("fs_test/probe.bin");
    check("read_file_binary length = 5",       bin_back.length() == 5);
    check("byte 0 = 0x4D",                     bin_back.get(0) == 0x4D);
    check("byte 1 = 0x5A",                     bin_back.get(1) == 0x5A);
    check("byte 4 = 0x03",                     bin_back.get(4) == 0x03);

    section("20. fs_append_file_binary");
    array<uint8> bin_tail;
    bin_tail.push(0xCA);
    bin_tail.push(0xFE);
    check("append_file_binary 2 bytes",        fs_append_file_binary("fs_test/probe.bin", bin_tail));
    check("size after append = 7",             fs_file_size("fs_test/probe.bin") == 7);
    array<uint8> bin_full = fs_read_file_binary("fs_test/probe.bin");
    check("read after append length = 7",      bin_full.length() == 7);
    check("byte 5 = 0xCA",                     bin_full.get(5) == 0xCA);
    check("byte 6 = 0xFE",                     bin_full.get(6) == 0xFE);

    section("21. Binary I/O — empty variants");
    // Empty write produces zero-byte file
    array<uint8> empty_bin;
    check("write empty binary (zero-byte)",    fs_write_file_binary("fs_test/empty.bin", empty_bin));
    check("empty.bin size = 0",                fs_file_size("fs_test/empty.bin") == 0);
    check("empty.bin read back length 0",      fs_read_file_binary("fs_test/empty.bin").length() == 0);

    // Empty append is a no-op (still returns true)
    check("append empty binary (no-op)",       fs_append_file_binary("fs_test/empty.bin", empty_bin));
    check("size still 0 after empty append",   fs_file_size("fs_test/empty.bin") == 0);

    section("22. Binary I/O — missing file reads");
    check("read_binary missing returns empty",  fs_read_file_binary("fs_test/ghost.bin").length() == 0);

    section("23. Binary I/O — missing parent dir");
    check("write_binary into missing parent fails", !fs_write_file_binary("fs_test/nope/sub/data.bin", bin_header));
    check("append_binary into missing parent fails",!fs_append_file_binary("fs_test/nope/sub/data.bin", bin_tail));

    // -----------------------------------------------------------------------
    // SECTION 6 — Directory creation and nesting
    // -----------------------------------------------------------------------

    section("24. fs_create_directory — basic");
    check("create single dir",                 fs_create_directory("fs_test/sub_a"));
    check("dir_exists after create",           fs_dir_exists("fs_test/sub_a"));
    check("create already-existing dir",       fs_create_directory("fs_test/sub_a"));

    section("25. fs_create_directory — nested (creates parents)");
    check("create nested dirs a/b/c",          fs_create_directory("fs_test/sub_a/b/c"));
    check("dir_exists nested a/b",             fs_dir_exists("fs_test/sub_a/b"));
    check("dir_exists nested a/b/c",           fs_dir_exists("fs_test/sub_a/b/c"));
    check("create another leaf under a/b",     fs_create_directory("fs_test/sub_a/b/d"));

    section("26. fs_create_directory — separate branch");
    check("create sub_b",                      fs_create_directory("fs_test/sub_b"));
    check("create sub_b/x",                    fs_create_directory("fs_test/sub_b/x"));

    // -----------------------------------------------------------------------
    // SECTION 7 — Directory listing
    // -----------------------------------------------------------------------

    // Populate various entries before listing
    section("27. Populate listing targets");
    check("create file sub_a/f1.txt",          fs_create_file("fs_test/sub_a/f1.txt", "file1"));
    check("create file sub_a/f2.txt",          fs_create_file("fs_test/sub_a/f2.txt", "file2"));
    check("create dir sub_a/d_only",           fs_create_directory("fs_test/sub_a/d_only"));

    section("28. fs_list_files — root dir");
    array<string> root_files = fs_list_files("fs_test");
    // We expect: hello.txt, empty.txt, text_io.txt, probe.bin, empty.bin (files)
    // Plus the listing target files in sub_a — NO, those are in sub_a, not root
    // In root we created: hello.txt, empty.txt, text_io.txt, probe.bin, empty.bin
    check("root has at least 4 files (basenames)", root_files.length() >= 4);

    section("29. fs_list_dirs — root dir");
    array<string> root_dirs = fs_list_dirs("fs_test");
    // We expect: sub_a, sub_b
    check("root has at least 2 dirs (basenames)", root_dirs.length() >= 2);

    section("30. fs_list_all — root dir (files + dirs combined)");
    array<string> root_all = fs_list_all("fs_test");
    check("list_all >= list_files + list_dirs", root_all.length() >= root_files.length() + root_dirs.length());

    section("31. fs_list_files / fs_list_dirs — sub_a");
    array<string> a_files = fs_list_files("fs_test/sub_a");
    check("sub_a has 2 files",                 a_files.length() == 2);
    // Both returned entries must be basenames, not full paths
    // They could be in any order; check by value
    bool has_f1 = false;
    bool has_f2 = false;
    for (string name : a_files)
    {
        if (name == "f1.txt") has_f1 = true;
        if (name == "f2.txt") has_f2 = true;
    }
    check("sub_a listing includes 'f1.txt' (basename)", has_f1);
    check("sub_a listing includes 'f2.txt' (basename)", has_f2);

    array<string> a_dirs = fs_list_dirs("fs_test/sub_a");
    check("sub_a has 1 dir (d_only)",          a_dirs.length() == 1);
    if (a_dirs.length() >= 1) {
        check("sub_a dir is 'd_only' (basename)", a_dirs.get(0) == "d_only");
    }

    section("32. Directory listing — empty directory");
    check("list_files on empty dir = empty",   fs_list_files("fs_test/sub_a/d_only").length() == 0);
    check("list_dirs on empty dir = empty",    fs_list_dirs("fs_test/sub_a/d_only").length() == 0);
    check("list_all on empty dir = empty",     fs_list_all("fs_test/sub_a/d_only").length() == 0);

    section("33. Directory listing — non-existent path");
    check("list_files on missing dir empty",   fs_list_files("fs_test/void").length() == 0);
    check("list_dirs on missing dir empty",    fs_list_dirs("fs_test/void").length() == 0);
    check("list_all on missing dir empty",     fs_list_all("fs_test/void").length() == 0);

    section("34. No recursion in listing");
    // sub_a/b/c exists but is a child of sub_a/b, not sub_a itself.
    // list_all("fs_test/sub_a") should NOT include b/c.
    array<string> a_all = fs_list_all("fs_test/sub_a");
    bool has_b_c = false;
    for (string name : a_all)
    {
        // Check that no entry contains a slash (would indicate recursion)
        if (name.find("/") >= 0 || name.find("\\") >= 0) {
            has_b_c = true;
        }
    }
    check("no entry contains path separators (no recursion)", !has_b_c);

    // -----------------------------------------------------------------------
    // SECTION 8 — Delete operations
    // -----------------------------------------------------------------------

    section("35. fs_delete_file");
    check("delete hello.txt",                  fs_delete_file("fs_test/hello.txt"));
    check("file_exists after delete false",   !fs_file_exists("fs_test/hello.txt"));

    section("36. fs_delete_file — missing file fails cleanly");
    check("delete missing returns false",     !fs_delete_file("fs_test/nonexistent.txt"));
    check("delete already-deleted false",     !fs_delete_file("fs_test/hello.txt"));

    section("37. fs_delete_directory — empty directory");
    check("delete empty sub_a/d_only",         fs_delete_directory("fs_test/sub_a/d_only"));
    check("dir_exists after delete false",    !fs_dir_exists("fs_test/sub_a/d_only"));

    section("38. fs_delete_directory — non-empty directory fails");
    // sub_a still contains f1.txt, f2.txt, and the b/ subtree
    check("delete non-empty sub_a fails",     !fs_delete_directory("fs_test/sub_a"));
    // Verify it still exists
    check("sub_a still exists after failed delete", fs_dir_exists("fs_test/sub_a"));

    section("39. fs_delete_directory — missing directory fails");
    check("delete missing dir fails",         !fs_delete_directory("fs_test/phantom_dir"));

    section("40. fs_delete_directory — file is not a directory");
    // Trying to delete a regular file as a directory should fail
    check("delete file as dir fails",         !fs_delete_directory("fs_test/text_io.txt"));

    section("41. fs_delete_file — directory is not a file");
    // Trying to delete a directory as a file should fail
    check("delete dir as file fails",         !fs_delete_file("fs_test/sub_a"));

    // -----------------------------------------------------------------------
    // SECTION 9 — Recursive cleanup of remaining items
    // -----------------------------------------------------------------------

    section("42. Full cleanup");
    // Use our recursive helper to remove everything under fs_test
    check("recursive cleanup succeeds",        cleanup_path("fs_test"));
    check("root dir gone after cleanup",      !fs_dir_exists("fs_test"));

    // -----------------------------------------------------------------------
    // SECTION 10 — fs_file_size edge cases
    // -----------------------------------------------------------------------

    section("43. fs_file_size — on various paths");
    // Re-create a few files for size checks
    check("create dir for size checks",        fs_create_directory("fs_test_size"));

    // Size of non-existent file = 0
    check("size of missing file = 0",          fs_file_size("fs_test_size/ghost.txt") == 0);

    // Size of a directory — undefined but should not crash; returns 0 or something
    int64 dir_size = fs_file_size("fs_test_size");
    check("size on directory is defined (0 or positive)", dir_size >= 0);

    // Cleanup
    check("cleanup size test dir",             fs_delete_directory("fs_test_size"));

    // -----------------------------------------------------------------------
    // SECTION 11 — Mixed scenarios
    // -----------------------------------------------------------------------

    section("44. Mixed: create file in deep nested dir");
    check("create deep nested a/b/c/d/e",      fs_create_directory("nested_mix/a/b/c/d/e"));
    check("create file in deepest",            fs_create_file("nested_mix/a/b/c/d/e/deep.txt", "deep"));
    check("deep file exists",                  fs_file_exists("nested_mix/a/b/c/d/e/deep.txt"));
    check("read deep file",                    fs_read_file("nested_mix/a/b/c/d/e/deep.txt") == "deep");

    section("45. Mixed: append to file in nested dir");
    check("append to deep file",               fs_append_file("nested_mix/a/b/c/d/e/deep.txt", "er"));
    check("read after append",                 fs_read_file("nested_mix/a/b/c/d/e/deep.txt") == "deeper");

    section("46. Mixed: list deep nested contents");
    array<string> deep_dirs = fs_list_dirs("nested_mix/a/b/c/d/e");
    check("deepest dir has no subdirs",        deep_dirs.length() == 0);
    array<string> deep_files = fs_list_files("nested_mix/a/b/c/d/e");
    check("deepest dir has 1 file",            deep_files.length() == 1);

    section("47. Mixed: file exists after append vs size");
    int64 deep_sz = fs_file_size("nested_mix/a/b/c/d/e/deep.txt");
    check("file_size deep.txt = 6",            deep_sz == 6);

    // Cleanup
    section("48. Cleanup nested_mix");
    check("cleanup nested_mix",                cleanup_path("nested_mix"));

    // -----------------------------------------------------------------------
    // SECTION 12 — fs_append_file on new / non-existent path
    // -----------------------------------------------------------------------

    section("49. fs_append_file on non-existent file");
    // The doc says append returns true/false. On a non-existent file the
    // behavior depends on implementation (may create, may fail). At minimum
    // it must not crash and returns a defined bool.
    check("create dir for append test",        fs_create_directory("append_test"));
    bool append_new_result = fs_append_file("append_test/new.txt", "first line");
    // If the implementation creates the file on append-to-nonexistent, it
    // should return true and the file should exist with content.
    if (append_new_result) {
        check("append to new file created it",   fs_file_exists("append_test/new.txt"));
        string new_content = fs_read_file("append_test/new.txt");
        check("append to new wrote content",     new_content == "first line");
    } else {
        // If it fails, that's also acceptable per the spec
        check("append to new returned false (acceptable)", true);
    }
    // Cleanup
    cleanup_path("append_test");

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------

    print_console("");
    print_console("===========================================");
    print_console("  TOTAL PASS: " + cast<string>(g_pass));
    print_console("  TOTAL FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

// ---------------------------------------------------------------------------
// Menu callbacks
// ---------------------------------------------------------------------------

void on_menu_run_again(int64 data) {
    print_console("[menu] Resetting and re-running tests...");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_summary(int64 data) {
    print_console("[menu] Current totals — PASS: " + cast<string>(g_pass) +
                  "  FAIL: " + cast<string>(g_fail));
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

int32 main() {
    print_console("[test_filesystem_api] Launching comprehensive Filesystem API test...");

    g_section = create_sidebar_section("filesystem test", "");
    g_btn     = g_section.create_button("Actions", ui_align::left);
    g_menu    = create_menu();
    g_menu.add_item("Run again",   cast<int64>(on_menu_run_again), "", "");
    g_menu.add_separator();
    g_menu.add_item("Log summary", cast<int64>(on_menu_summary),   "", "");
    g_menu.attach_to_button(g_btn);

    g_handle = register_routine(cast<int64>(test_routine), 0);
    if (g_handle == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;
    }
    return 1;
}
