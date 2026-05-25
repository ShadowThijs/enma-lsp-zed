// =============================================================================
// File System API smoke test — sandboxed I/O isolated to perception_main_dir
//
// Mirrors `test_proc_api.em` shape (single-shot routine, sidebar menu).
// Verifies every native + sandbox escape attempts.
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

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

void test_routine(int64 data) {
    if (g_done == 1) return;
    g_done = 1;

    print_console("=== File System API Tests ===");

    section("Sandbox escape attempts (should all fail)");
    check("absolute path C:\\... rejected",  !fs_create_file("C:\\evil.txt", "x"));
    check("absolute path / rejected",        !fs_create_file("/etc/passwd", "x"));
    check("UNC path rejected",               !fs_create_file("\\\\server\\share\\f", "x"));
    check("../ rejected",                    !fs_create_file("../escape.txt", "x"));
    check("nested ../ rejected",             !fs_create_file("ok/../escape.txt", "x"));
    check("chats/ rejected",                 !fs_create_file("chats/leak.txt", "x"));
    check("CHATS/ rejected (case-insens)",   !fs_create_file("CHATS/leak.txt", "x"));
    check("empty path rejected",             !fs_create_file("", "x"));

    section("Basic file ops");
    check("create_file",                      fs_create_file("test_fs.txt", "hello world"));
    check("file_exists after create",         fs_file_exists("test_fs.txt"));
    check("file_size matches",                fs_file_size("test_fs.txt") == 11);
    check("read_file content",                fs_read_file("test_fs.txt") == "hello world");

    check("write_file (overwrite)",           fs_write_file("test_fs.txt", "replaced"));
    check("read after overwrite",             fs_read_file("test_fs.txt") == "replaced");

    check("append_file",                      fs_append_file("test_fs.txt", " + appended"));
    check("read after append",                fs_read_file("test_fs.txt") == "replaced + appended");

    check("delete_file",                      fs_delete_file("test_fs.txt"));
    check("file_exists after delete",        !fs_file_exists("test_fs.txt"));

    section("Directory ops");
    check("create_directory",                 fs_create_directory("test_fs_dir"));
    check("dir_exists",                       fs_dir_exists("test_fs_dir"));
    check("create file in dir",               fs_create_file("test_fs_dir/inner.txt", "inner"));

    array<string> files = fs_list_files("test_fs_dir");
    check("list_files count",                 files.length() == 1);

    check("delete inner file",                fs_delete_file("test_fs_dir/inner.txt"));
    check("delete_directory",                 fs_delete_directory("test_fs_dir"));
    check("dir_exists after delete",         !fs_dir_exists("test_fs_dir"));

    section("Binary I/O");
    array<uint8> bin;
    bin.push(0xDE); bin.push(0xAD); bin.push(0xBE); bin.push(0xEF);
    check("write_file_binary",                fs_write_file_binary("test_bin.bin", bin));
    check("file_size binary",                 fs_file_size("test_bin.bin") == 4);

    array<uint8> read_back = fs_read_file_binary("test_bin.bin");
    check("read_file_binary length",          read_back.length() == 4);
    check("byte 0 = 0xDE",                    read_back.get(0) == 0xDE);
    check("byte 3 = 0xEF",                    read_back.get(3) == 0xEF);

    array<uint8> more;
    more.push(0xCA); more.push(0xFE);
    check("append_file_binary",               fs_append_file_binary("test_bin.bin", more));
    check("size after append",                fs_file_size("test_bin.bin") == 6);

    check("cleanup: delete bin",              fs_delete_file("test_bin.bin"));

    section("Missing-file handling");
    check("read missing returns empty",       fs_read_file("does_not_exist.txt") == "");
    check("read_binary missing empty",        fs_read_file_binary("does_not_exist.bin").length() == 0);
    check("file_size missing == 0",           fs_file_size("does_not_exist.txt") == 0);
    check("delete missing fails cleanly",    !fs_delete_file("does_not_exist.txt"));

    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

void on_menu_run_again(int64 data) {
    print_console("[menu] resetting + re-firing");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_summary(int64 data) {
    print_console("[menu] PASS=" + cast<string>(g_pass) +
                  " FAIL=" + cast<string>(g_fail));
}

int32 main() {
    print_console("[test_filesystem_api] launching");

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
