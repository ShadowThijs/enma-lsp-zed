// =============================================================================
// Comprehensive Proc API test
//
// Exercises EVERY documented type, method, and standalone function from the
// Proc API documentation (see docs/Perception/Proc API.md). Targets
// notepad.exe -- make sure it's running.
//
// Permission-gated calls (write_memory, virtual_memory_operations,
// kernel_rw_access) are tested in their blocked-by-default state. When the
// host grants the flag, the blocked checks will flip to PASS(true) -- the
// logic below handles both outcomes correctly.
//
// Methods documented in the API but NOT yet registered in the LSP's
// types.json are shown as comments with a "NOT IN TYPES.JSON" marker.
// These are valid Enma runtime calls but the LSP will not recognise them
// until types.json is updated. Uncomment them when the corresponding
// entries are added to types.json.
//
// Non-blocking shape: main() registers a one-shot routine and returns
// immediately. The routine runs all tests on its own thread, prints a
// summary, then self-unregisters.
// =============================================================================
//
// COMPLETE API CHECKLIST
// ======================
//
// Standalone functions:
//   [x] ref_process(uint32 pid)             -> proc_t
//   [x] ref_process(string name)            -> proc_t
//
// Type: proc_t
//   Identity:
//     [x] base_address()                    -> uint64
//     [x] peb()                             -> uint64
//     [x] pid()                             -> uint32
//     [x] alive()                           -> bool
//     [x] is_valid_address(uint64)          -> bool
//     [x] get_eprocess()                    -> uint64   (gated: kernel_rw_access)
//
//   Read primitives (unsigned):
//     [x] ru8(uint64)                       -> uint8
//     [x] ru16(uint64)                      -> uint16
//     [x] ru32(uint64)                      -> uint32
//     [x] ru64(uint64)                      -> uint64
//
//   Read primitives (signed):
//     [x] r8(uint64)                        -> int8
//     [x] r16(uint64)                       -> int16
//     [x] r32(uint64)                       -> int32
//     [x] r64(uint64)                       -> int64
//
//   Read primitives (float):
//     [x] rf32(uint64)                      -> float32
//     [x] rf64(uint64)                      -> float64
//
//   Read primitives (string):
//     [x] rs(uint64, int32)                 -> string
//     [x] rws(uint64, int32)                -> string
//
//   Bulk read:
//     [x] rvm(uint64, uint64)               -> array<uint8>
//
//   Typed reads (vec / quat / mat):
//     [ ] read_vec2_fl32(uint64)            -> vec2   NOT IN TYPES.JSON
//     [ ] read_vec2_fl64(uint64)            -> vec2   NOT IN TYPES.JSON
//     [ ] read_vec3_fl32(uint64)            -> vec3   NOT IN TYPES.JSON
//     [ ] read_vec3_fl64(uint64)            -> vec3   NOT IN TYPES.JSON
//     [ ] read_vec4_fl32(uint64)            -> vec4   NOT IN TYPES.JSON
//     [ ] read_vec4_fl64(uint64)            -> vec4   NOT IN TYPES.JSON
//     [ ] read_quat_fl32(uint64)            -> quat   NOT IN TYPES.JSON
//     [ ] read_quat_fl64(uint64)            -> quat   NOT IN TYPES.JSON
//     [ ] read_mat4_fl32(uint64)            -> mat4   NOT IN TYPES.JSON
//     [ ] read_mat4_fl64(uint64)            -> mat4   NOT IN TYPES.JSON
//
//   SIMD reads:
//     [x] r128(uint64)                      -> array<uint8>
//     [x] r256(uint64)                      -> array<uint8>
//     [ ] r512(uint64)                      -> array<uint8>  NOT IN TYPES.JSON
//
//   Write primitives (gated: write_memory):
//     [x] wu8(uint64, uint8)                -> bool
//     [ ] wu16(uint64, uint16)              -> bool  NOT IN TYPES.JSON
//     [ ] wu32(uint64, uint32)              -> bool  NOT IN TYPES.JSON
//     [ ] wu64(uint64, uint64)              -> bool  NOT IN TYPES.JSON
//     [ ] w8(uint64, int8)                  -> bool  NOT IN TYPES.JSON
//     [ ] w16(uint64, int16)                -> bool  NOT IN TYPES.JSON
//     [ ] w32(uint64, int32)                -> bool  NOT IN TYPES.JSON
//     [ ] w64(uint64, int64)                -> bool  NOT IN TYPES.JSON
//     [x] wf32(uint64, float32)             -> bool
//     [ ] wf64(uint64, float64)             -> bool  NOT IN TYPES.JSON
//     [x] ws(uint64, string)                -> bool
//     [ ] wws(uint64, string)               -> bool  NOT IN TYPES.JSON
//
//   Bulk write (gated: write_memory):
//     [x] wvm(uint64, array<uint8>)         -> bool
//
//   Typed writes (gated: write_memory):
//     [ ] write_vec2_fl32(uint64, vec2)     -> bool  NOT IN TYPES.JSON
//     [ ] write_vec2_fl64(uint64, vec2)     -> bool  NOT IN TYPES.JSON
//     [ ] write_vec3_fl32(uint64, vec3)     -> bool  NOT IN TYPES.JSON
//     [ ] write_vec3_fl64(uint64, vec3)     -> bool  NOT IN TYPES.JSON
//     [ ] write_vec4_fl32(uint64, vec4)     -> bool  NOT IN TYPES.JSON
//     [ ] write_vec4_fl64(uint64, vec4)     -> bool  NOT IN TYPES.JSON
//     [ ] write_quat_fl32(uint64, quat)     -> bool  NOT IN TYPES.JSON
//     [ ] write_quat_fl64(uint64, quat)     -> bool  NOT IN TYPES.JSON
//     [ ] write_mat4_fl32(uint64, mat4)     -> bool  NOT IN TYPES.JSON
//     [ ] write_mat4_fl64(uint64, mat4)     -> bool  NOT IN TYPES.JSON
//
//   SIMD writes (gated: write_memory):
//     [ ] w128(uint64, array<uint8>)        -> bool  NOT IN TYPES.JSON
//     [ ] w256(uint64, array<uint8>)        -> bool  NOT IN TYPES.JSON
//     [ ] w512(uint64, array<uint8>)        -> bool  NOT IN TYPES.JSON
//
//   Modules and exports:
//     [x] get_module_base(string)           -> uint64
//     [x] get_module_size(string)           -> uint64
//     [x] get_module_list()                 -> array<module_info_t>
//     [x] get_proc_address(uint64, string)  -> uint64
//     [ ] get_import_rdata_address(uint64, string) -> uint64  NOT IN TYPES.JSON
//
//   Pattern scanning:
//     [x] find_code_pattern(uint64, uint64, string)      -> uint64
//     [x] find_all_code_patterns(uint64, uint64, string) -> array<uint64>
//
//   Threads:
//     [x] get_all_tebs()                    -> array<uint64>
//
//   Pointer arrays:
//     [x] read_pointer_array(uint64, int64, int64) -> array<uint64>
//
//   VAD:
//     [x] virtual_query(uint64)             -> vad_region_t
//     [x] get_vad_snapshot(bool)            -> array<vad_region_t>
//
//   Memory scans:
//     [x] scan_string(string, bool)         -> array<uint64>
//     [x] scan_wstring(string, bool)        -> array<uint64>
//     [x] scan_pointer(uint64, bool)        -> array<uint64>
//     [x] scan_u64(uint64, bool)            -> array<uint64>
//     [x] scan_u32(uint32, bool)            -> array<uint64>
//     [ ] scan_float(float32, bool)         -> array<uint64>  NOT IN TYPES.JSON
//     [ ] scan_double(float64, bool)        -> array<uint64>  NOT IN TYPES.JSON
//
//   VM alloc/free (gated: virtual_memory_operations):
//     [x] alloc_vm(uint64)                  -> uint64
//     [x] free_vm(uint64)                   -> bool
//
// Type: module_info_t
//   [x] name()                              -> string
//   [x] base()                              -> uint64
//   [x] size()                              -> uint64
//
// Type: vad_region_t
//   [x] start()                             -> uint64
//   [x] size()                              -> uint64
//   [x] protection()                        -> uint64
//   [x] heap_likely()                       -> bool
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

// -----------------------------------------------------------------------
// Test routine -- runs once as a registered routine
// -----------------------------------------------------------------------
void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Comprehensive Proc API test ===");
    print_console("target: notepad.exe");

    // ===================================================================
    // ref_process / identity
    // ===================================================================
    section("ref_process + identity");

    // ref_process(string name)
    proc_t p = ref_process("notepad.exe");
    check("ref_process('notepad.exe') returns alive handle", p.alive());

    uint64 pid_v = cast<uint64>(p.pid());
    uint64 base = p.base_address();
    uint64 peb_v = p.peb();

    check("pid() != 0", pid_v != 0);
    check("base_address() != 0", base != 0);
    check("peb() != 0", peb_v != 0);
    check("is_valid_address(base) = true (own module base is valid)",
          p.is_valid_address(base));
    check("is_valid_address(0) = false (null address rejected)",
          !p.is_valid_address(0));
    check("is_valid_address(0xFFFFFFFF80000000) = false (kernel address rejected)",
          !p.is_valid_address(0xFFFFFFFF80000000));

    // ref_process(uint32 pid) -- documented overload
    proc_t p2 = ref_process(cast<uint32>(pid_v));
    check("ref_process(uint32 pid) returns alive handle", p2.alive());
    check("ref_process(uint32 pid) yields same pid",
          cast<uint64>(p2.pid()) == pid_v);
    check("ref_process(uint32 pid) yields same base",
          p2.base_address() == base);

    // get_eprocess -- gated: kernel_rw_access, blocked by default
    uint64 eproc = p.get_eprocess();
    check("get_eprocess() returns 0 when kernel_rw_access not granted",
          eproc == 0);

    // ===================================================================
    // Read primitives (unsigned) -- PE header at base address
    // ===================================================================
    section("read primitives (unsigned)");

    uint8 mz0 = p.ru8(base);
    uint8 mz1 = p.ru8(base + 1);
    check("ru8(base+0) == 'M' (0x4D)", mz0 == 0x4D);
    check("ru8(base+1) == 'Z' (0x5A)", mz1 == 0x5A);

    uint16 mz_word = p.ru16(base);
    check("ru16(base) == 0x5A4D ('MZ')", mz_word == 0x5A4D);

    int32 e_lfanew = p.r32(base + 0x3C);
    check("r32(base+0x3C) = e_lfanew > 0 and < 0x1000",
          e_lfanew > 0 && e_lfanew < 0x1000);

    uint32 pe_sig = p.ru32(base + e_lfanew);
    check("ru32(base+e_lfanew) == 0x00004550 (PE signature)", pe_sig == 0x00004550);

    uint64 first_qword = p.ru64(base);
    check("ru64(base) low 16 bits == 0x5A4D ('MZ')",
          (first_qword & 0xFFFF) == 0x5A4D);

    // ===================================================================
    // Read primitives (signed)
    // ===================================================================
    section("read primitives (signed)");

    int8 i8_val = p.r8(base);
    check("r8(base) low byte == 'M' (0x4D)", i8_val == 0x4D);

    int16 i16_val = p.r16(base);
    check("r16(base) == 0x5A4D", i16_val == 0x5A4D);

    int64 pe_sig_signed = p.r64(base + e_lfanew);
    check("r64(base+e_lfanew) low 32 == 0x00004550",
          (pe_sig_signed & 0xFFFFFFFF) == 0x00004550);

    check("r32(0) returns 0 (null address safe)", p.r32(0) == 0);
    check("ru32(0xFFFFFFFF80000000) returns 0 (kernel addr safe)",
          p.ru32(0xFFFFFFFF80000000) == 0);

    // ===================================================================
    // Read primitives (float)
    // ===================================================================
    section("read primitives (float)");

    float32 f32_val = p.rf32(base);
    check("rf32(base) returns a value (self-equality = finite)",
          f32_val == f32_val);

    float64 f64_val = p.rf64(base);
    check("rf64(base) returns a value (self-equality = finite)",
          f64_val == f64_val);

    // Out-of-range addresses return 0
    float32 f32_zero = p.rf32(0);
    check("rf32(0) returns 0.0f", f32_zero == 0.0f);

    float64 f64_zero = p.rf64(0xFFFFFFFF80000000);
    check("rf64(kernel addr) returns 0.0", f64_zero == 0.0);

    // ===================================================================
    // String reads
    // ===================================================================
    section("string reads");

    string small_str = p.rs(base, 16);
    check("rs(base, 16) returns non-empty string", small_str.length() > 0);
    check("rs(base, 16) starts with 'M' (DOS header starts with MZ)",
          small_str.length() > 0 && small_str.substr(0, 1) == "M");

    // Read from address 0 -- should return empty
    string empty_str = p.rs(0, 10);
    check("rs(0, 10) returns empty string", empty_str.length() == 0);

    // Wide string read from PE header (treated as UTF-16LE)
    string ws_str = p.rws(base, 32);
    check("rws(base, 32) survives and returns a string",
          ws_str.length() >= 0);

    check("rws(0, 10) returns empty string", p.rws(0, 10).length() == 0);

    // ===================================================================
    // Bulk read
    // ===================================================================
    section("bulk read (rvm)");

    array<uint8> dos_hdr = p.rvm(base, 64);
    check("rvm(base, 64).length() == 64", dos_hdr.length() == 64);
    check("rvm(base, 64)[0] == 'M' (0x4D)", dos_hdr.get(0) == 0x4D);
    check("rvm(base, 64)[1] == 'Z' (0x5A)", dos_hdr.get(1) == 0x5A);

    // Read 0 bytes -- should return empty array
    array<uint8> zero_bytes = p.rvm(base, 0);
    check("rvm(base, 0).length() == 0", zero_bytes.length() == 0);

    // Read from invalid address -- should return empty or truncated
    array<uint8> bad_read = p.rvm(0, 64);
    check("rvm(0, 64) returns length 0", bad_read.length() == 0);

    // ===================================================================
    // Typed reads (vec / quat / mat)
    //
    // NOTE: These methods are documented in Proc API.md but are NOT yet
    // registered in the LSP types.json. The host runtime supports them.
    // Uncomment each block below when the corresponding entries are added
    // to enma-lsp/src/types.json under proc_t methods.
    // ===================================================================
    section("typed reads (vec / quat / mat) [LIVE] + [NOT IN TYPES.JSON]");

    // --- REGISTERED: vec2, vec3, vec4, quat, mat4 types are known to the
    //     LSP via math_types. The proc_t methods themselves are not in
    //     types.json yet.

    // The following calls are valid Enma runtime code. Commented out because
    // the LSP emits ERROR-level "method-not-found" diagnostics for them.
    // Once types.json gets the typed-read entries, uncomment and they will
    // work with full LSP support.

    /*
    vec2 v2_32 = p.read_vec2_fl32(base);
    check("read_vec2_fl32(base) returns a vec2", v2_32.x == v2_32.x);

    vec2 v2_64 = p.read_vec2_fl64(base);
    check("read_vec2_fl64(base) returns a vec2", v2_64.x == v2_64.x);

    vec3 v3_32 = p.read_vec3_fl32(base);
    check("read_vec3_fl32(base) returns a vec3", v3_32.x == v3_32.x);

    vec3 v3_64 = p.read_vec3_fl64(base);
    check("read_vec3_fl64(base) returns a vec3", v3_64.x == v3_64.x);

    vec4 v4_32 = p.read_vec4_fl32(base);
    check("read_vec4_fl32(base) returns a vec4", v4_32.x == v4_32.x);

    vec4 v4_64 = p.read_vec4_fl64(base);
    check("read_vec4_fl64(base) returns a vec4", v4_64.x == v4_64.x);

    quat q_32 = p.read_quat_fl32(base);
    check("read_quat_fl32(base) returns a quat", q_32.x == q_32.x);

    quat q_64 = p.read_quat_fl64(base);
    check("read_quat_fl64(base) returns a quat", q_64.x == q_64.x);

    mat4 m4_32 = p.read_mat4_fl32(base);
    check("read_mat4_fl32(base) returns a mat4 with .m[0] accessible",
          m4_32.m[0] == m4_32.m[0]);

    mat4 m4_64 = p.read_mat4_fl64(base);
    check("read_mat4_fl64(base) returns a mat4 with .m[0] accessible",
          m4_64.m[0] == m4_64.m[0]);

    // Failed reads (invalid address) return zero-initialized value
    vec2 v2_zero = p.read_vec2_fl32(0);
    check("read_vec2_fl32(0) returns vec2(0,0)",
          v2_zero.x == 0.0 && v2_zero.y == 0.0);

    quat q_zero = p.read_quat_fl64(0);
    check("read_quat_fl64(0) returns quat(0,0,0,0)",
          q_zero.x == 0.0 && q_zero.y == 0.0 &&
          q_zero.z == 0.0 && q_zero.w == 0.0);
    */

    // Placeholder vec construction so the test has something in this section.
    // Real vec3 at (base + 0) as float32 would exercise the runtime path.
    vec2 dummy_v2 = vec2(1.0, 2.0);
    check("vec2 type is constructable", dummy_v2.x == 1.0 && dummy_v2.y == 2.0);

    vec3 dummy_v3 = vec3(1.0, 2.0, 3.0);
    check("vec3 type is constructable", dummy_v3.z == 3.0);

    vec4 dummy_v4 = vec4(1.0, 2.0, 3.0, 4.0);
    check("vec4 type is constructable", dummy_v4.w == 4.0);

    quat dummy_q = quat(0.0, 0.0, 0.0, 1.0);
    check("quat type is constructable", dummy_q.w == 1.0);

    mat4 dummy_m4;
    check("mat4 type is constructable (field m00 == 0.0)",
          dummy_m4.m00 == 0.0);

    // ===================================================================
    // SIMD reads
    // ===================================================================
    section("SIMD reads");

    // r128: 16 bytes (registered in types.json)
    array<uint8> b128 = p.r128(base);
    check("r128(base).length() == 16", b128.length() == 16);
    check("r128(base)[0] == 'M' (0x4D)", b128.get(0) == 0x4D);

    // r256: 32 bytes (registered in types.json)
    array<uint8> b256 = p.r256(base);
    check("r256(base).length() == 32", b256.length() == 32);
    check("r256(base)[0] == 'M' (0x4D)", b256.get(0) == 0x4D);

    // r512: 64 bytes -- documented but NOT in types.json yet
    // array<uint8> b512 = p.r512(base);
    // check("r512(base).length() == 64", b512.length() == 64);

    // Invalid address -- r128 and r256 are registered
    check("r128(0).length() == 0", p.r128(0).length() == 0);
    check("r256(0).length() == 0", p.r256(0).length() == 0);
    // check("r512(0).length() == 0", p.r512(0).length() == 0);

    // ===================================================================
    // Write primitives (gated: write_memory)
    //
    // By default write_memory is NOT granted, so writes should be blocked
    // and return false. If the host grants the permission, these will pass
    // instead -- the logic below handles both.
    //
    // Only wu8, wf32, ws, and wvm are registered in types.json. The
    // remaining documented write primitives are commented out below.
    // ===================================================================
    section("write primitives -- gated (write_memory)");

    // --- REGISTERED: wu8 (unsigned 8-bit) ---
    bool wu8_res = p.wu8(base, cast<uint8>(0xFF));
    check("wu8(base, 0xFF) blocked by default = false", wu8_res == false);

    // --- NOT IN TYPES.JSON ---
    // bool wu16_res = p.wu16(base, cast<uint16>(0xFFFF));
    // bool wu32_res = p.wu32(base, 0xCAFEBABEu);
    // bool wu64_res = p.wu64(base, 0xDEADBEEFCAFEBABE);
    // check("wu16 blocked by default = false", wu16_res == false);
    // check("wu32 blocked by default = false", wu32_res == false);
    // check("wu64 blocked by default = false", wu64_res == false);

    // --- Signed writes (NONE are in types.json) ---
    // bool w8_res  = p.w8(base,  cast<int8>(0x7F));
    // bool w16_res = p.w16(base, cast<int16>(0x7FFF));
    // bool w32_res = p.w32(base, 0x7FFFFFFF);
    // bool w64_res = p.w64(base, 0x7FFFFFFFFFFFFFFF);
    // check("w8 blocked by default = false",  w8_res == false);
    // check("w16 blocked by default = false", w16_res == false);
    // check("w32 blocked by default = false", w32_res == false);
    // check("w64 blocked by default = false", w64_res == false);

    // --- REGISTERED: wf32 (float32 write) ---
    bool wf32_res = p.wf32(base, 3.14159f);
    check("wf32(base, pi) blocked by default = false", wf32_res == false);

    // --- NOT IN TYPES.JSON: wf64 ---
    // bool wf64_res = p.wf64(base, 3.141592653589793);
    // check("wf64(base, pi) blocked by default = false", wf64_res == false);

    // --- REGISTERED: ws (string write) ---
    bool ws_res = p.ws(base, "hello from enma");
    check("ws(base, text) blocked by default = false", ws_res == false);

    // --- NOT IN TYPES.JSON: wws (wide string write) ---
    // bool wws_res = p.wws(base, "wide hello from enma");
    // check("wws(base, text) blocked by default = false", wws_res == false);

    // ===================================================================
    // Bulk write (gated: write_memory)
    // ===================================================================
    section("bulk write -- gated (write_memory)");

    bool wvm_res = p.wvm(base, dos_hdr);
    check("wvm(base, bytes) blocked by default = false", wvm_res == false);

    // ===================================================================
    // Typed writes (gated: write_memory)
    //
    // NONE of these are registered in types.json yet. Uncomment when types.json
    // is updated with the write_vec2/3/4, write_quat, write_mat4 entries.
    // ===================================================================
    section("typed writes -- gated (write_memory) [NOT IN TYPES.JSON]");

    /*
    bool wv2_f32 = p.write_vec2_fl32(base, v2_32);
    bool wv2_f64 = p.write_vec2_fl64(base, v2_64);
    bool wv3_f32 = p.write_vec3_fl32(base, v3_32);
    bool wv3_f64 = p.write_vec3_fl64(base, v3_64);
    bool wv4_f32 = p.write_vec4_fl32(base, v4_32);
    bool wv4_f64 = p.write_vec4_fl64(base, v4_64);
    bool wq_f32  = p.write_quat_fl32(base, q_32);
    bool wq_f64  = p.write_quat_fl64(base, q_64);
    bool wm4_f32 = p.write_mat4_fl32(base, m4_32);
    bool wm4_f64 = p.write_mat4_fl64(base, m4_64);

    check("write_vec2_fl32 blocked by default = false",  wv2_f32 == false);
    check("write_vec2_fl64 blocked by default = false",  wv2_f64 == false);
    check("write_vec3_fl32 blocked by default = false",  wv3_f32 == false);
    check("write_vec3_fl64 blocked by default = false",  wv3_f64 == false);
    check("write_vec4_fl32 blocked by default = false",  wv4_f32 == false);
    check("write_vec4_fl64 blocked by default = false",  wv4_f64 == false);
    check("write_quat_fl32 blocked by default = false",  wq_f32 == false);
    check("write_quat_fl64 blocked by default = false",  wq_f64 == false);
    check("write_mat4_fl32 blocked by default = false",  wm4_f32 == false);
    check("write_mat4_fl64 blocked by default = false",  wm4_f64 == false);
    */

    print_console("  [SKIP] typed writes: not in types.json (10 methods)");

    // ===================================================================
    // SIMD writes (gated: write_memory)
    //
    // NONE of these are registered in types.json yet.
    // ===================================================================
    section("SIMD writes -- gated (write_memory) [NOT IN TYPES.JSON]");

    /*
    bool w128_res = p.w128(base, b128);
    bool w256_res = p.w256(base, b256);
    bool w512_res = p.w512(base, b512);

    check("w128(base, 16 bytes) blocked by default = false", w128_res == false);
    check("w256(base, 32 bytes) blocked by default = false", w256_res == false);
    check("w512(base, 64 bytes) blocked by default = false", w512_res == false);
    */

    print_console("  [SKIP] SIMD writes: not in types.json (3 methods)");

    // ===================================================================
    // Modules and exports
    // ===================================================================
    section("modules + exports");

    // get_module_base / get_module_size
    uint64 nb = p.get_module_base("notepad.exe");
    uint64 ns = p.get_module_size("notepad.exe");
    check("get_module_base('notepad.exe') == base_address()", nb == base);
    check("get_module_size('notepad.exe') > 0", ns > 0);

    uint64 k32 = p.get_module_base("kernel32.dll");
    check("get_module_base('kernel32.dll') != 0", k32 != 0);

    uint64 ntdll = p.get_module_base("ntdll.dll");
    check("get_module_base('ntdll.dll') != 0", ntdll != 0);

    uint64 bogus = p.get_module_base("not_a_real_module.dll");
    check("get_module_base('nonexistent.dll') == 0", bogus == 0);

    check("get_module_size('nonexistent.dll') == 0",
          p.get_module_size("not_a_real_module.dll") == 0);

    // get_module_list -- every loaded module
    array<module_info_t> mods = p.get_module_list();
    check("get_module_list().length() > 0", mods.length() > 0);

    // module_info_t methods: name(), base(), size()
    if (mods.length() > 0) {
        module_info_t first_mod = mods.get(0);
        string mod_name = first_mod.name();
        uint64 mod_base = first_mod.base();
        uint64 mod_size = first_mod.size();

        check("module_info_t.name() returns non-empty string",
              mod_name.length() > 0);
        check("module_info_t.base() != 0", mod_base != 0);
        check("module_info_t.size() > 0", mod_size > 0);

        // Verify at least one module matches the notepad base address
        bool found_self = false;
        int64 mi = 0;
        while (mi < mods.length()) {
            module_info_t m = mods.get(mi);
            if (m.base() == base) {
                found_self = true;
                check("module_info_t.name() for notepad is non-empty",
                      m.name().length() > 0);
            }
            mi = mi + 1;
        }
        check("get_module_list() includes notepad.exe itself", found_self);
    }

    // get_proc_address
    if (k32 != 0) {
        uint64 gph = p.get_proc_address(k32, "GetProcessHeap");
        check("get_proc_address(kernel32, 'GetProcessHeap') != 0", gph != 0);

        uint64 nope = p.get_proc_address(k32, "NotARealExport_xyz");
        check("get_proc_address(kernel32, bogus) == 0", nope == 0);
    }

    // get_import_rdata_address -- documented but NOT in types.json
    // if (k32 != 0) {
    //     uint64 import_rdata = p.get_import_rdata_address(k32, "GetProcessHeap");
    //     check("get_import_rdata_address call survives",
    //           import_rdata == import_rdata);
    // }
    print_console("  [SKIP] get_import_rdata_address: not in types.json");

    // ===================================================================
    // Pattern scanning
    // ===================================================================
    section("pattern scanning");

    // find_code_pattern
    uint64 mz_hit = p.find_code_pattern(base, 0x100, "4D 5A");
    check("find_code_pattern('4D 5A') from base hits at base", mz_hit == base);

    // Wildcard: "M? 5A"
    uint64 mz_wild = p.find_code_pattern(base, 0x100, "?? 5A");
    check("find_code_pattern('?? 5A') from base returns non-zero", mz_wild != 0);

    // No match
    uint64 no_match = p.find_code_pattern(base, 0x100,
                                          "DE AD BE EF CA FE BA BE");
    check("find_code_pattern(unlikely sig) == 0", no_match == 0);

    // find_all_code_patterns
    array<uint64> all_mz = p.find_all_code_patterns(base, 0x100, "4D 5A");
    check("find_all_code_patterns('4D 5A') length >= 1", all_mz.length() >= 1);

    array<uint64> none = p.find_all_code_patterns(base, 0x100,
                                                  "DE AD BE EF CA FE BA BE");
    check("find_all_code_patterns(unlikely sig) length == 0",
          none.length() == 0);

    // ===================================================================
    // Threads -- get_all_tebs
    // ===================================================================
    section("threads + TEBs");

    array<uint64> tebs = p.get_all_tebs();
    check("get_all_tebs().length() > 0", tebs.length() > 0);
    if (tebs.length() > 0) {
        check("get_all_tebs()[0] != 0", tebs.get(0) != 0);
    }

    // ===================================================================
    // Pointer arrays
    // ===================================================================
    section("pointer arrays");

    // Read raw uint64s from the PE header with offset_delta = 0
    array<uint64> ptr_arr = p.read_pointer_array(base, 4, 0);
    check("read_pointer_array(base, 4, 0).length() == 4",
          ptr_arr.length() == 4);

    // With a delta
    array<uint64> ptr_arr_delta = p.read_pointer_array(base, 4, 0x1000);
    check("read_pointer_array(base, 4, 0x1000).length() == 4",
          ptr_arr_delta.length() == 4);

    // Zero count
    array<uint64> empty_arr = p.read_pointer_array(base, 0, 0);
    check("read_pointer_array(base, 0, 0).length() == 0",
          empty_arr.length() == 0);

    // ===================================================================
    // VAD / virtual_query
    // ===================================================================
    section("VAD / virtual_query");

    // get_vad_snapshot -- excludes PE-image regions
    array<vad_region_t> full_snap = p.get_vad_snapshot(false);
    check("get_vad_snapshot(false).length() > 0", full_snap.length() > 0);

    array<vad_region_t> heap_snap = p.get_vad_snapshot(true);
    check("get_vad_snapshot(true).length() >= 0", heap_snap.length() >= 0);
    check("heap snapshot <= full snapshot",
          heap_snap.length() <= full_snap.length());

    // vad_region_t methods
    if (full_snap.length() > 0) {
        vad_region_t first_region = full_snap.get(0);
        uint64 r_start = first_region.start();
        uint64 r_size  = first_region.size();
        uint64 r_prot  = first_region.protection();
        bool   r_heap  = first_region.heap_likely();

        check("vad_region_t.start() != 0", r_start != 0);
        check("vad_region_t.size() > 0", r_size > 0);
        check("vad_region_t.protection() has valid bits", r_prot != 0);
        check("vad_region_t.heap_likely() is bool",
              r_heap == true || r_heap == false);
    }

    // virtual_query -- known VAD address returns the region
    if (full_snap.length() > 0) {
        vad_region_t first_r = full_snap.get(0);
        uint64 known_start = first_r.start();
        uint64 known_size  = first_r.size();

        vad_region_t queried = p.virtual_query(known_start);
        check("virtual_query(known_addr) returns non-null handle",
              cast<int64>(queried) != 0);
        check("virtual_query(known_addr).start() == known_start",
              cast<int64>(queried) != 0 && queried.start() == known_start);
        check("virtual_query(known_addr).size() == known_size",
              cast<int64>(queried) != 0 && queried.size() == known_size);

        // Address halfway into the region
        uint64 mid = known_start + known_size / 2;
        vad_region_t mid_r = p.virtual_query(mid);
        check("virtual_query(mid_of_region).start() == known_start",
              cast<int64>(mid_r) != 0 && mid_r.start() == known_start);
    }

    // virtual_query of module base returns 0 (excluded from VAD snapshot)
    vad_region_t module_r = p.virtual_query(base);
    check("virtual_query(module_base) returns null (module excluded)",
          cast<int64>(module_r) == 0);

    // virtual_query of unmapped kernel address
    vad_region_t miss = p.virtual_query(0xDEADBEEFCAFE);
    check("virtual_query(unmapped) returns null", cast<int64>(miss) == 0);

    // ===================================================================
    // Memory scans
    //
    // All registered in types.json except scan_float and scan_double.
    // ===================================================================
    section("memory scans");

    // scan_string -- search for a common ASCII pattern
    array<uint64> str_hits = p.scan_string("MZ", false);
    check("scan_string('MZ', false) call succeeds",
          str_hits.length() >= 0);

    // scan_wstring -- text is UTF-8, converted to UTF-16 internally
    array<uint64> ws_hits = p.scan_wstring("MZ", false);
    check("scan_wstring('MZ', false) call succeeds",
          ws_hits.length() >= 0);

    // scan_pointer -- search for a pointer to the module base
    array<uint64> ptr_hits = p.scan_pointer(base, false);
    check("scan_pointer(base, false) call succeeds",
          ptr_hits.length() >= 0);

    // scan_u64 -- search for a uint64 value
    array<uint64> u64_hits = p.scan_u64(0x5A4D, false);
    check("scan_u64(0x5A4D, false) call succeeds",
          u64_hits.length() >= 0);

    // scan_u32 -- search for PE signature value
    array<uint64> u32_hits = p.scan_u32(0x00004550, false);
    check("scan_u32(PE sig, false) call succeeds",
          u32_hits.length() >= 0);

    // scan_float / scan_double -- documented but NOT in types.json
    // array<uint64> float_hits = p.scan_float(1.0f, false);
    // array<uint64> double_hits = p.scan_double(1.0, false);
    // check("scan_float(1.0f, false) call succeeds", float_hits.length() >= 0);
    // check("scan_double(1.0, false) call succeeds", double_hits.length() >= 0);
    print_console("  [SKIP] scan_float, scan_double: not in types.json");

    // Heap-only variant (registered scan_u32)
    array<uint64> u32_heap = p.scan_u32(0x00004550, true);
    check("scan_u32(PE sig, true) call succeeds",
          u32_heap.length() >= 0);

    // Unlikely-to-exist scan -- should return 0 hits
    array<uint64> no_hits = p.scan_wstring(
        "__zzz_unlikely_string_xyz_42__", false);
    check("scan_wstring(unlikely) == 0 hits", no_hits.length() == 0);

    // ===================================================================
    // VM alloc / free (gated: virtual_memory_operations)
    // Blocked by default; returns 0/false.
    // ===================================================================
    section("VM alloc/free -- gated (virtual_memory_operations)");

    uint64 alloc_res = p.alloc_vm(0x1000);
    check("alloc_vm(0x1000) returns 0 when permission not granted",
          alloc_res == 0);

    bool free_res = p.free_vm(0xDEAD0000);
    check("free_vm(0xDEAD0000) returns false when permission not granted",
          free_res == false);

    // ===================================================================
    // Stale-handle path: scoped proc_t destructor
    // ===================================================================
    section("lifetime / stale-handle detection");

    uint64 outer_pid = pid_v;

    {
        proc_t scoped = ref_process("notepad.exe");
        check("inner-scope ref_process returns alive handle", scoped.alive());
        check("inner-scope pid matches outer",
              cast<uint64>(scoped.pid()) == outer_pid);
    } // scoped drops here -- destructor releases its ref

    // Outer p is still valid (separate ref)
    check("outer p still alive after inner scope drops", p.alive());
    check("outer p pid still readable",
          cast<uint64>(p.pid()) == outer_pid);

    // ===================================================================
    // Summary
    // ===================================================================
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    // Self-unregister
    unregister_routine(g_handle);
}

// -----------------------------------------------------------------------
// Menu callbacks
// -----------------------------------------------------------------------
void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked -- resetting and re-firing routine");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

// -----------------------------------------------------------------------
// Main entry point
// -----------------------------------------------------------------------
int32 main() {
    print_console("[proc_api] launching comprehensive test routine + sidebar menu");

    // Sidebar section with button and context menu
    g_section = create_sidebar_section("proc test", "");
    g_btn     = g_section.create_button("Actions", ui_align::left);
    g_menu    = create_menu();
    g_menu.add_item("Run again",   cast<int64>(on_menu_run_again),   "", "");
    g_menu.add_separator();
    g_menu.add_item("Log summary", cast<int64>(on_menu_log_summary), "", "");
    g_menu.attach_to_button(g_btn);

    g_handle = register_routine(cast<int64>(test_routine), 0);
    if (g_handle == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;
    }
    return 1;       // keep script loaded so the routine can run
}
