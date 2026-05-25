// =============================================================================
// Proc API smoke test for notepad.exe
//
// Run with notepad.exe open. Exercises every registered proc_t method and
// the global ref_process() variants. Prints PASS/FAIL per test plus a final
// summary. Assumes write_memory and virtual_memory_operations permissions
// are NOT granted (default) — the gated tests pass when blocked, fail if
// unexpectedly allowed through.
//
// To verify the permission gates DO let writes through when granted, set
// `enma_lang::api_permissions[enma_lang::write_memory] = true;` host-side
// before load_script and rerun — the gated_writes_blocked tests will then
// flip to "succeeded" (which the script reports correctly either way).
//
// Non-blocking shape: main() registers a single-shot routine and returns
// immediately. The routine runs all tests on its own thread so the UI stays
// responsive, then self-unregisters.
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

// GUI handles — owned by the script's gui_* lists, but kept as globals so
// the routine callback can still reach them (and so they don't read as
// stack-scoped temporaries).
sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

void check(string label, bool ok) {
    if (ok) {
        print_console("[PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print_console("[FAIL] " + label);
        g_fail = g_fail + 1;
    }
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

void test_routine(int64 data) {
    // Single-shot. Tick fires every ~1ms; we run once and self-unregister.
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== proc API smoke test ===");
    print_console("target: notepad.exe");

    // -----------------------------------------------------------------------
    // ref_process / lifetime
    // -----------------------------------------------------------------------
    section("ref_process + identity");

    proc_t p = ref_process("notepad.exe");
    check("ref_process('notepad.exe') returns alive handle", p.alive());

    int64 pid_v = p.pid();
    int64 base = p.base_address();
    int64 peb_v = p.peb();

    check("pid() != 0", pid_v != 0);
    check("base_address() != 0", base != 0);
    check("peb() != 0", peb_v != 0);
    check("is_valid_address(base) = true", p.is_valid_address(base));
    check("is_valid_address(0) = false", !p.is_valid_address(0));
    // Kernel-space address — usermode check rejects, no VAD lookup needed
    check("is_valid_address(0xFFFFFFFF80000000) = false (kernel)",
          !p.is_valid_address(0xFFFFFFFF80000000));

    // ref_process by pid (round-trip the pid we just got)
    proc_t p2 = ref_process(cast<uint32>(pid_v));
    check("ref_process(pid) returns alive handle", p2.alive());
    check("ref_process(pid) yields same base", p2.base_address() == base);

    // -----------------------------------------------------------------------
    // Reads (PE header bytes)
    // -----------------------------------------------------------------------
    section("read primitives (PE header)");

    // DOS header MZ at base + 0
    uint8 mz0 = p.ru8(base + 0);
    uint8 mz1 = p.ru8(base + 1);
    check("ru8(base+0) == 'M'", mz0 == 0x4D);
    check("ru8(base+1) == 'Z'", mz1 == 0x5A);

    uint16 mz_word = p.ru16(base);
    check("ru16(base) == 0x5A4D ('MZ')", mz_word == 0x5A4D);

    // PE signature offset is at DOS header offset 0x3C, PE\0\0 = 0x00004550
    int32 e_lfanew = p.r32(base + 0x3C);
    check("e_lfanew (DOS+0x3C) > 0 and < 0x1000", e_lfanew > 0 && e_lfanew < 0x1000);

    uint32 pe_sig = p.ru32(base + e_lfanew);
    check("ru32(base+e_lfanew) == 0x00004550 (PE)", pe_sig == 0x00004550);

    int64 pe64_sig = p.r64(base);
    check("r64(base) low byte is 'M'", (pe64_sig & 0xFF) == 0x4D);

    uint64 ru64_v = p.ru64(base);
    check("ru64(base) low 16 == 0x5A4D", (ru64_v & 0xFFFF) == 0x5A4D);

    // Negative-addr / kernel-addr should reject
    check("ru32(0) returns 0 (not crash)", p.ru32(0) == 0);
    check("ru32(0xFFFFFFFF80000000) returns 0 (kernel)",
          p.ru32(0xFFFFFFFF80000000) == 0);

    // -----------------------------------------------------------------------
    // Bulk read
    // -----------------------------------------------------------------------
    section("bulk read (rvm)");

    array<uint8> dos = p.rvm(base, 64);
    check("rvm(base, 64).length() == 64", dos.length() == 64);
    check("rvm[0] == 'M'", dos.get(0) == 0x4D);
    check("rvm[1] == 'Z'", dos.get(1) == 0x5A);

    // r128: 16 bytes of DOS header
    array<uint8> dos16 = p.r128(base);
    check("r128(base).length() == 16", dos16.length() == 16);
    check("r128(base)[0] == 'M'", dos16.get(0) == 0x4D);

    array<uint8> dos32 = p.r256(base);
    check("r256(base).length() == 32", dos32.length() == 32);

    // -----------------------------------------------------------------------
    // Module enumeration
    // -----------------------------------------------------------------------
    section("modules + exports");

    int64 nb = p.get_module_base("notepad.exe");
    int64 ns = p.get_module_size("notepad.exe");
    check("get_module_base('notepad.exe') == base_address()", nb == base);
    check("get_module_size('notepad.exe') > 0", ns > 0);

    int64 k32 = p.get_module_base("kernel32.dll");
    check("get_module_base('kernel32.dll') != 0", k32 != 0);

    int64 ntdll = p.get_module_base("ntdll.dll");
    check("get_module_base('ntdll.dll') != 0", ntdll != 0);

    int64 bogus = p.get_module_base("not_a_real_module.dll");
    check("get_module_base('not_a_real_module.dll') == 0", bogus == 0);

    // Exports
    if (k32 != 0) {
        int64 gph = p.get_proc_address(k32, "GetProcessHeap");
        check("get_proc_address(k32, 'GetProcessHeap') != 0", gph != 0);

        int64 nope = p.get_proc_address(k32, "NotARealExport_xyz");
        check("get_proc_address bogus name == 0", nope == 0);
    }

    // -----------------------------------------------------------------------
    // Pattern scanning (in PE text)
    // -----------------------------------------------------------------------
    section("pattern scanning");

    // PE signature itself: 4D 5A (MZ). Should hit at base.
    int64 mz_hit = p.find_code_pattern(base, 0x100, "4D 5A");
    check("find_code_pattern('4D 5A') from base hits at base", mz_hit == base);

    // Wildcard match: "M? 5A"
    int64 mz_wild = p.find_code_pattern(base, 0x100, "?? 5A");
    check("find_code_pattern('?? 5A') hits", mz_wild != 0);

    // No match
    int64 no_match = p.find_code_pattern(base, 0x100, "DE AD BE EF CA FE BA BE");
    check("find_code_pattern of unlikely sig == 0", no_match == 0);

    // -----------------------------------------------------------------------
    // TEB enumeration
    // -----------------------------------------------------------------------
    section("threads + TEBs");

    array<int64> tebs = p.get_all_tebs();
    check("get_all_tebs().length() > 0", tebs.length() > 0);
    check("first TEB is non-zero", tebs.get(0) != 0);

    // -----------------------------------------------------------------------
    // virtual_query / VAD snapshot
    // -----------------------------------------------------------------------
    section("VAD / virtual_query");

    // NOTE: snapshot excludes module/image memory — only private/heap regions.
    array<vad_region_t> snap = p.get_vad_snapshot(false);
    check("get_vad_snapshot(false) has regions", snap.length() > 0);

    array<vad_region_t> heap_only = p.get_vad_snapshot(true);
    check("get_vad_snapshot(true) <= total",
          heap_only.length() <= snap.length());

    // virtual_query of a module base returns 0 (modules aren't in snap).
    vad_region_t r_module = p.virtual_query(base);
    check("virtual_query(module base) returns 0 (modules not in snapshot)",
          cast<int64>(r_module) == 0);

    // virtual_query of a known-in-snapshot address (the first region's start)
    // should return its own region.
    if (snap.length() >= 1) {
        vad_region_t first = snap.get(0);
        int64 known_addr = first.start();
        int64 known_size = first.size();
        vad_region_t r = p.virtual_query(known_addr);
        check("virtual_query(known_addr) returns non-null", cast<int64>(r) != 0);
        check("virtual_query(known_addr).start == known_addr",
              cast<int64>(r) != 0 && r.start() == known_addr);
        check("virtual_query(known_addr).size == known_size",
              cast<int64>(r) != 0 && r.size() == known_size);
        // Address halfway into that region should still resolve to it.
        int64 mid = known_addr + known_size / 2;
        vad_region_t r_mid = p.virtual_query(mid);
        check("virtual_query(mid_of_region).start == known_addr",
              cast<int64>(r_mid) != 0 && r_mid.start() == known_addr);
    }

    // Kernel-space (unmapped) returns 0. 0xDEADBEEFCAFE is past usermode max.
    vad_region_t miss = p.virtual_query(0xDEADBEEFCAFE);
    check("virtual_query(unmapped) returns 0", cast<int64>(miss) == 0);

    // -----------------------------------------------------------------------
    // Memory scans
    // -----------------------------------------------------------------------
    section("memory scans");

    // Scan for the PE signature value. Should find at least one hit (the PE
    // header itself) on heap_only=false. May be slow on large processes.
    array<int64> u32_hits = p.scan_u32(0x00004550, false);
    check("scan_u32(PE sig, false).length() > 0", u32_hits.length() > 0);

    // Scan for a wide string value that's unlikely to exist
    array<int64> nope_w = p.scan_wstring("__zzz_unlikely_string_xyz_42__", false);
    check("scan_wstring(unlikely) == 0 hits", nope_w.length() == 0);

    // -----------------------------------------------------------------------
    // Permission gates (write / vm)
    // -----------------------------------------------------------------------
    section("permission gates");

    // wu8 should be blocked by default. Returns false (0) without faulting.
    bool wu8_blocked = !p.wu8(base, 0xFF);
    check("wu8 blocked when write_memory = false", wu8_blocked);

    bool wf32_blocked = !p.wf32(base, 1.5f);
    check("wf32 blocked when write_memory = false", wf32_blocked);

    bool ws_blocked = !p.ws(base, "deny");
    check("ws blocked when write_memory = false", ws_blocked);

    bool wvm_blocked = !p.wvm(base, dos);
    check("wvm blocked when write_memory = false", wvm_blocked);

    // alloc_vm gated by virtual_memory_operations
    int64 alloc_blocked = p.alloc_vm(0x1000);
    check("alloc_vm blocked when virtual_memory_operations = false",
          alloc_blocked == 0);

    bool free_blocked = !p.free_vm(0xDEAD0000);
    check("free_vm blocked when virtual_memory_operations = false", free_blocked);

    // -----------------------------------------------------------------------
    // Stale-handle path: re-fetch the same proc and let the original drop
    // -----------------------------------------------------------------------
    section("stale-handle detection");

    {
        proc_t scoped = ref_process("notepad.exe");
        int64 spid = scoped.pid();
        check("inner-scope ref_process returns alive handle", scoped.alive());
        check("inner-scope pid matches", spid == pid_v);
    } // scoped drops here — destructor releases its ref

    // The outer p is still valid (separate ref). Methods still work.
    check("outer p still alive after inner drop", p.alive());
    check("outer p pid still readable", p.pid() == pid_v);

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    // Self-unregister. Called from the routine's own thread → flips an
    // orphaned flag + requests termination; the thread's exit path
    // destroys the routine struct itself.
    unregister_routine(g_handle);
}

// Menu callback — fires when a menu item is clicked.
void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked — resetting and re-firing routine");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

int32 main() {
    print_console("[test_proc_api] launching test routine + sidebar menu");

    // Sidebar section + button → context menu. Globals so they outlive
    // main() — host ownership is in script->gui_* lists; cleanup runs
    // automatically at script unload.
    g_section = create_sidebar_section("proc test", "");
    g_btn     = g_section.create_button("Actions", ui_align::left);
    g_menu    = create_menu();
    g_menu.add_item("Run again",   cast<int64>(on_menu_run_again),   "", "");
    g_menu.add_separator();
    g_menu.add_item("Log summary", cast<int64>(on_menu_log_summary), "", "");
    // attach_to_button makes the menu open as a context menu on the
    // button's right-click (or click depending on host wiring).
    g_menu.attach_to_button(g_btn);

    g_handle = register_routine(cast<int64>(test_routine), 0);
    if (g_handle == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;  // explicit fail-unload
    }
    return 1;       // keep script loaded so the routine can run
}
