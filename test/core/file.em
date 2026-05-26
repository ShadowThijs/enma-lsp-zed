// =============================================================================
// File addon API comprehensive smoke test
//
// Exercises every native registered by the File addon:
//
// Type: file_t  (stream handle)
//   - file_open(path, mode) -> file_t          (constructor)
//   - f.is_open()            -> bool
//   - f.is_eof()             -> bool
//   - f.read_all()           -> string
//   - f.read_line()          -> string
//   - f.write(string)        -> int64
//   - f.flush()
//   - f.size()               -> int64
//   - f.tell()               -> int64
//   - f.seek(int64)
//   - f.close()
//
// Whole-file convenience:
//   - file_read(path)        -> string
//   - file_write(path, str)  -> bool
//   - file_read_bytes(path)  -> array  (uint8 stride-1)
//   - file_write_bytes(path, array) -> bool
//
// Filesystem operations:
//   - file_exists(path)      -> bool
//   - file_remove(path)      -> bool
//   - file_rename(from, to)  -> bool
//   - file_copy(src, dst)    -> bool
//   - file_size(path)        -> int64
//   - file_mtime(path)       -> int64
//
// Directory operations:
//   - dir_exists(path)       -> bool
//   - dir_create(path)       -> bool
//   - dir_list(path)         -> array  (string[])
//   - dir_walk(path)         -> array  (string[])
// =============================================================================

string g_tmpdir = "./__file_test_tmp__";

int64 g_pass = 0;
int64 g_fail = 0;

void check(string label, bool ok) {
    if (ok) {
        print("[PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print("[FAIL] " + label);
        g_fail = g_fail + 1;
    }
}

void section(string title) {
    print("");
    print("--- " + title + " ---");
}

// ---------------------------------------------------------------------------
// Setup: create a temp working directory.
// ---------------------------------------------------------------------------
void setup() {
    dir_create(g_tmpdir);
}

// ---------------------------------------------------------------------------
// Teardown: clean up temp files.
// ---------------------------------------------------------------------------
void teardown() {
    // Walk all files and remove them, then remove the directory.
    array<string> all = dir_walk(g_tmpdir);
    int64 i = 0;
    while (i < all.length()) {
        file_remove(all.get(i));
        i = i + 1;
    }
    dir_list(g_tmpdir);  // just call it, don't assert on empty
    file_remove(g_tmpdir); // dir_remove equivalent — try to remove dir
    // Use file_remove on the directory as well
    file_remove(g_tmpdir);
}

// ===========================================================================
// 1. stream API — file_t type: open modes, read / write / seek
// ===========================================================================
void test_stream_write_and_read() {
    section("file_t — write then read back");

    // --- Write mode ---
    string path = g_tmpdir + "/stream_test.txt";
    file_t w = file_open(path, "w");
    check("file_open('w') returns open handle", w.is_open());

    int64 written = w.write("Hello, File API!\n");
    check("file_t.write() returns bytes written", written > 0);

    w.write("Line two.\n");
    w.write("Line three.\n");

    w.flush();
    check("file_t.flush() survives", true);

    int64 sz = w.size();
    check("file_t.size() > 0 after writes", sz > 0);
    print("  file size after writes: " + cast<string>(sz));

    int64 pos = w.tell();
    check("file_t.tell() matches size at end", pos == sz);

    w.close();
    check("file_t.is_open() false after close", !w.is_open());

    // --- Re-open for reading ---
    file_t r = file_open(path, "r");
    check("file_open('r') returns open handle", r.is_open());

    check("!file_t.is_eof() at start with content", !r.is_eof());

    string line1 = r.read_line();
    check("file_t.read_line() first line matches", line1 == "Hello, File API!");
    print("  line1: '" + line1 + "'");

    string line2 = r.read_line();
    check("file_t.read_line() second line matches", line2 == "Line two.");

    // Seek back to start
    r.seek(0);
    int64 after_seek = r.tell();
    check("file_t.tell() == 0 after seek(0)", after_seek == 0);

    // read_all from start
    string all = r.read_all();
    check("file_t.read_all() returns full content", all.length() > 0);
    check("file_t.read_all() starts correctly",
          all == "Hello, File API!\nLine two.\nLine three.\n");
    check("file_t.is_eof() true after reading all", r.is_eof());

    r.close();
    check("file_t.is_open() false after second close", !r.is_open());

    // --- Binary write mode ---
    file_t wb = file_open(path, "wb");
    check("file_open('wb') succeeds", wb.is_open());

    int64 bw = wb.write("binary content\x00with null");
    check("file_t.write() binary mode", bw > 0);

    wb.close();
    check("file_t write+close binary mode survives", true);

    // --- Append mode ---
    file_t a = file_open(path, "a");
    check("file_open('a') succeeds", a.is_open());

    a.write("appended line\n");
    a.close();
    check("file_t append + close survives", true);

    // --- Read+ mode ---
    file_t rp = file_open(path, "r+");
    check("file_open('r+') succeeds", rp.is_open());
    check("file_t.size() > 0 for existing file", rp.size() > 0);
    rp.close();

    // --- Write+ mode ---
    file_t wp = file_open(path, "w+");
    check("file_open('w+') succeeds", wp.is_open());
    check("file_t.size() == 0 after w+ truncation", wp.size() == 0);
    wp.close();

    // --- Open failure ---
    file_t bad = file_open("/nonexistent/path/file.txt", "r");
    check("file_open(nonexistent, 'r') !is_open()", !bad.is_open());
    check("file_t.is_eof() false on failed open", !bad.is_eof());
    bad.close();  // should be safe to close even on failed open
    check("file_t.close() on failed open survives", true);
}

// ===========================================================================
// 2. whole-file convenience functions
// ===========================================================================
void test_whole_file_convenience() {
    section("whole-file convenience — file_read / file_write");

    string path = g_tmpdir + "/convenience.txt";
    string content = "This is a convenience file.\nWith two lines.\n";

    // file_write
    bool wok = file_write(path, content);
    check("file_write() returns true", wok);

    // file_read
    string read_back = file_read(path);
    check("file_read() returns correct content", read_back == content);

    // file_read_bytes
    section("whole-file convenience — file_read_bytes / file_write_bytes");

    array<uint8> bytes = file_read_bytes(path);
    check("file_read_bytes() returns non-empty array", bytes.length() > 0);
    check("file_read_bytes() length matches string length",
          bytes.length() == content.length());
    print("  read " + cast<string>(bytes.length()) + " bytes");

    // file_write_bytes
    string binpath = g_tmpdir + "/binary.out";
    bool wbok = file_write_bytes(binpath, bytes);
    check("file_write_bytes() returns true", wbok);

    array<uint8> read_back_bytes = file_read_bytes(binpath);
    check("file_write_bytes() round-trip matches length",
          read_back_bytes.length() == bytes.length());
}

// ===========================================================================
// 3. filesystem operations — file-level
// ===========================================================================
void test_filesystem_file_ops() {
    section("filesystem — file-level operations");

    string path  = g_tmpdir + "/fs_test.txt";
    string path2 = g_tmpdir + "/fs_test_renamed.txt";
    string path3 = g_tmpdir + "/fs_test_copied.txt";

    // Create a file first
    file_write(path, "filesystem test content");

    // file_exists
    bool exists = file_exists(path);
    check("file_exists() returns true for existing file", exists);

    bool not_exists = file_exists("/nonexistent/path/file.txt");
    check("file_exists() returns false for missing file", !not_exists);

    // file_size
    int64 sz = file_size(path);
    check("file_size() returns positive value", sz > 0);
    print("  file_size = " + cast<string>(sz));

    int64 bad_sz = file_size("/nonexistent/path/file.txt");
    check("file_size() returns -1 for missing file", bad_sz == -1);

    // file_mtime
    int64 mt = file_mtime(path);
    check("file_mtime() returns non-negative value", mt >= 0);
    print("  file_mtime = " + cast<string>(mt) + " (Unix seconds)");

    int64 bad_mt = file_mtime("/nonexistent/path/file.txt");
    check("file_mtime() returns -1 for missing file", bad_mt == -1);

    // file_rename
    bool renamed = file_rename(path, path2);
    check("file_rename() returns true", renamed);
    check("file_rename() — old path no longer exists", !file_exists(path));
    check("file_rename() — new path exists", file_exists(path2));

    // file_copy
    bool copied = file_copy(path2, path3);
    check("file_copy() returns true", copied);
    check("file_copy() — source still exists", file_exists(path2));
    check("file_copy() — destination exists", file_exists(path3));

    // file_copy overwrites dst — copy again (should succeed)
    bool copied_again = file_copy(path2, path3);
    check("file_copy() overwrites existing dst", copied_again);

    // file_remove
    bool removed = file_remove(path2);
    check("file_remove() returns true", removed);
    check("file_remove() — file no longer exists", !file_exists(path2));

    // Remove remaining
    file_remove(path3);
    check("file_remove() — last file cleaned up", !file_exists(path3));
}

// ===========================================================================
// 4. filesystem operations — directory-level
// ===========================================================================
void test_filesystem_dir_ops() {
    section("filesystem — directory-level operations");

    string subdir1 = g_tmpdir + "/subdir_a";
    string subdir2 = g_tmpdir + "/subdir_b";
    string nested  = subdir1 + "/nested";

    // dir_exists
    bool top_exists = dir_exists(g_tmpdir);
    check("dir_exists() returns true for existing dir", top_exists);

    bool not_dir = dir_exists("/nonexistent_dir_xyz");
    check("dir_exists() returns false for missing dir", !not_dir);

    // dir_create
    bool created1 = dir_create(subdir1);
    check("dir_create() returns true for new dir", created1);

    // dir_create on existing directory (should succeed)
    bool created_again = dir_create(subdir1);
    check("dir_create() succeeds on existing dir", created_again);

    bool created2 = dir_create(subdir2);
    check("dir_create() second subdir succeeds", created2);

    // dir_create nested
    bool created_nested = dir_create(nested);
    check("dir_create() nested dir succeeds", created_nested);

    // dir_list
    array<string> entries = dir_list(g_tmpdir);
    check("dir_list() returns entries", entries.length() > 0);
    print("  dir_list found " + cast<string>(entries.length()) + " entries");

    // Verify entries contain subdirectory names
    int64 i = 0;
    bool found_a = false;
    bool found_b = false;
    while (i < entries.length()) {
        if (entries.get(i) == "subdir_a") { found_a = true; }
        if (entries.get(i) == "subdir_b") { found_b = true; }
        i = i + 1;
    }
    check("dir_list() contains 'subdir_a'", found_a);
    check("dir_list() contains 'subdir_b'", found_b);

    // dir_walk
    array<string> walk_entries = dir_walk(g_tmpdir);
    check("dir_walk() returns entries", walk_entries.length() > 0);
    print("  dir_walk found " + cast<string>(walk_entries.length()) + " entries");

    // Walk should include full paths
    int64 j = 0;
    bool walked_nested = false;
    bool walked_subdir_a = false;
    while (j < walk_entries.length()) {
        string entry = walk_entries.get(j);
        if (entry == nested || entry.find("nested") >= 0) {
            walked_nested = true;
        }
        if (entry == subdir1 || entry.find("subdir_a") >= 0) {
            walked_subdir_a = true;
        }
        j = j + 1;
    }
    check("dir_walk() finds nested subdirectory", walked_nested);
    check("dir_walk() finds subdir_a", walked_subdir_a);

    // Clean up created directories (use file_remove on empty dirs)
    file_remove(nested);
    file_remove(subdir1);
    file_remove(subdir2);

    check("dir_exists() false after removing subdir1", !dir_exists(subdir1));
    check("dir_exists() false after removing subdir2", !dir_exists(subdir2));
    check("dir_exists() true for original tmpdir", dir_exists(g_tmpdir));
}

// ===========================================================================
// 5. edge cases — empty file, large write, read past EOF, etc.
// ===========================================================================
void test_edge_cases() {
    section("edge cases");

    // --- Empty file ---
    string empty_path = g_tmpdir + "/empty.txt";
    file_write(empty_path, "");

    string empty_read = file_read(empty_path);
    check("file_read() on empty file returns empty string", empty_read == "");

    array<uint8> empty_bytes = file_read_bytes(empty_path);
    check("file_read_bytes() on empty file returns 0-length array",
          empty_bytes.length() == 0);

    int64 empty_sz = file_size(empty_path);
    check("file_size() on empty file returns 0", empty_sz == 0);

    file_t ef = file_open(empty_path, "r");
    check("file_open(empty, 'r') is_open()", ef.is_open());
    check("file_t.is_eof() true on empty file", ef.is_eof());

    string eoline = ef.read_line();
    check("file_t.read_line() on empty file returns ''", eoline == "");

    string eoall = ef.read_all();
    check("file_t.read_all() on empty file returns ''", eoall == "");
    ef.close();

    // --- Seek to end and read_all should return empty ---
    file_t sf = file_open(empty_path, "r");  // use existing empty file
    // Actually use a non-empty file for more interesting seek tests
    sf.close();

    string nonempty_path = g_tmpdir + "/seek_test.txt";
    file_write(nonempty_path, "ABCDEFGHIJ");

    file_t nf = file_open(nonempty_path, "r");
    nf.seek(5);
    check("file_t.tell() == 5 after seek(5)", nf.tell() == 5);

    string remainder = nf.read_all();
    check("file_t.read_all() from mid-file returns remainder",
          remainder == "FGHIJ");
    nf.close();

    // --- Seek past end (behavior is implementation-defined, just verify no fault) ---
    file_t pf = file_open(nonempty_path, "r");
    pf.seek(9999);
    // No crash is the assertion
    check("file_t.seek(past EOF) does not crash", true);

    // read_all at past-EOF position should return empty
    string past = pf.read_all();
    check("file_t.read_all() after seek past EOF returns ''", past == "");
    pf.close();

    file_remove(nonempty_path);
    file_remove(empty_path);

    // --- Write zero bytes ---
    string zero_path = g_tmpdir + "/zero_write.txt";
    file_t zw = file_open(zero_path, "w");
    int64 zwritten = zw.write("");
    check("file_t.write('') returns 0", zwritten == 0);
    zw.close();
    file_remove(zero_path);

    // --- file_open with all documented modes ---
    section("file_t — all documented open modes");

    string modepath = g_tmpdir + "/modes.txt";
    file_t mr = file_open(modepath, "r");
    check("file_open('r') on missing file fails", !mr.is_open());
    mr.close();

    file_t mw = file_open(modepath, "w");
    check("file_open('w') on new file succeeds", mw.is_open());
    mw.write("mode test");
    mw.close();

    file_t mrb = file_open(modepath, "rb");
    check("file_open('rb') succeeds", mrb.is_open());
    mrb.close();

    file_t mwb = file_open(modepath, "wb");
    check("file_open('wb') succeeds", mwb.is_open());
    mwb.close();

    file_t mab = file_open(modepath, "ab");
    check("file_open('ab') succeeds", mab.is_open());
    mab.close();

    file_t mrp = file_open(modepath, "r+");
    check("file_open('r+') on existing file succeeds", mrp.is_open());
    mrp.close();

    file_t mwp = file_open(modepath, "w+");
    check("file_open('w+') on existing file succeeds", mwp.is_open());
    mwp.close();

    file_remove(modepath);
}

// ===========================================================================
// 6. directory ops — list empty dir, non-existent dir
// ===========================================================================
void test_dir_edge_cases() {
    section("directory edge cases");

    // dir_list on non-existent path
    array<string> bad_list = dir_list("/nonexistent_dir_xyz");
    check("dir_list() on missing path returns empty array",
          bad_list.length() == 0);

    // dir_walk on non-existent path
    array<string> bad_walk = dir_walk("/nonexistent_dir_xyz");
    check("dir_walk() on missing path returns empty array",
          bad_walk.length() == 0);

    // dir_exists on a file path (should still return true if it exists)
    string filepath = g_tmpdir + "/not_a_dir.txt";
    file_write(filepath, "i am a file");
    bool file_is_dir = dir_exists(filepath);
    // dir_exists on a regular file is platform-dependent;
    // just verify no crash
    check("dir_exists() on a file path survives", file_is_dir == file_is_dir);
    file_remove(filepath);

    // dir_create with empty string — verify no fault
    // (behavior undefined, just confirm it doesn't crash)
    // bool empty_dir = dir_create("");

    // dir_list on empty dir
    string emptydir = g_tmpdir + "/empty_dir";
    dir_create(emptydir);
    array<string> empty_list = dir_list(emptydir);
    check("dir_list() on empty dir returns empty array",
          empty_list.length() == 0);
    file_remove(emptydir);
}

// ===========================================================================
// 7. main — orchestrate the test routines
// ===========================================================================
int32 main() {
    print("=== File addon API smoke test ===");

    setup();

    test_stream_write_and_read();
    test_whole_file_convenience();
    test_filesystem_file_ops();
    test_filesystem_dir_ops();
    test_edge_cases();
    test_dir_edge_cases();

    teardown();

    print("");
    print("===========================================");
    print("  PASS: " + cast<string>(g_pass));
    print("  FAIL: " + cast<string>(g_fail));
    print("===========================================");

    return 0;
}
