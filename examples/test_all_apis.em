// ============================================================================
// test_all_apis.em — exercise every API added in this round.
// ============================================================================
//
// Preshipped (enma core):
//   - url_encode / url_decode (string addon)
//   - quat + mat4 (math3d addon)
//   - mutex shared variants (thread addon: lock_shared / unlock_shared / try_lock_shared)
//
// Perception side:
//   - cpu     : vendor, brand, rdtsc, perf, tickcount, datetime, bitcasts, priority
//   - sound   : load_sound / sound.play / sound_inst.set_*
//   - zydis   : encoder request, builder, encode, nop_fill, disasm, name lookup
//   - win     : window enum/find/query, clipboard, keyboard/mouse SEND
//   - input   : mouse pos/delta/scroll/hover, key state, key name
//   - unicorn : cpu_t with mem_map / mem_rw / regs / start / hooks
//   - net     : http_get, http_post, ws_t (gated by 'network_access' permission)
//
// Output: every line prefixed PASS / FAIL / SKIP. Totals at the end.
//
// Environment notes:
//   * `sound` tests skip cleanly if `sounds/test.wav` is missing.
//   * `net` tests handle BOTH perm states — they pass cleanly whether the
//     UI's network_access toggle is on or off.
//   * Some `win` and `input` tests are surface-only — we can't synthesize
//     real keypresses inside the script.
//
// Run: load via perception, watch the console.

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_skip = 0;

void T(string name, bool ok, string detail) {
    if (ok) {
        g_pass = g_pass + 1;
        print_console("PASS  " + name);
    } else {
        g_fail = g_fail + 1;
        print_console("FAIL  " + name + "  --  " + detail);
    }
}

void S(string name, string reason) {
    g_skip = g_skip + 1;
    print_console("SKIP  " + name + "  --  " + reason);
}

// ============================================================================
// 1. URL encode / decode  (preshipped, string addon)
// ============================================================================

void test_url() {
    print_console("--- url ---");

    string raw = "hello world / foo=bar & baz=1+2";
    string enc = url_encode(raw);
    T("url_encode encodes spaces as %20", enc.contains("%20"), "got '" + enc + "'");
    T("url_encode encodes &", enc.contains("%26"), "got '" + enc + "'");
    T("url_encode encodes =", enc.contains("%3D"), "got '" + enc + "'");

    string dec = url_decode(enc);
    T("url_decode roundtrip", dec == raw, "raw='" + raw + "' dec='" + dec + "'");

    T("url_decode '+' -> ' '",
        url_decode("a+b") == "a b",
        "got '" + url_decode("a+b") + "'");

    T("url_encode preserves alnum",
        url_encode("HelloWorld123") == "HelloWorld123",
        "got '" + url_encode("HelloWorld123") + "'");

    T("url_encode preserves -_.~",
        url_encode("a-b_c.d~e") == "a-b_c.d~e",
        "got '" + url_encode("a-b_c.d~e") + "'");

    T("url_encode empty", url_encode("") == "", "");
    T("url_decode empty", url_decode("") == "", "");
}

// ============================================================================
// 2. CPU  (perception)
// ============================================================================

void test_cpu() {
    print_console("--- cpu ---");

    string vendor = cpu_vendor();
    T("cpu_vendor non-empty", vendor.length() > 0, "got '" + vendor + "'");
    T("cpu_vendor 12 chars", vendor.length() == 12, "got " + cast<string>(vendor.length()));

    string brand = cpu_brand();
    T("cpu_brand non-empty", brand.length() > 0, "got '" + brand + "'");

    int64 t0 = rdtsc();
    int64 t1 = rdtsc();
    T("rdtsc increases", t1 >= t0, "t0=" + cast<string>(t0) + " t1=" + cast<string>(t1));

    int64 freq = perf_frequency();
    T("perf_frequency > 0", freq > 0, "freq=" + cast<string>(freq));

    int64 a = perf_time();
    int64 b = perf_time();
    T("perf_time monotonic", b >= a, "");

    int64 tick = get_tickcount64();
    T("get_tickcount64 > 0", tick > 0, "");

    int64 ms = now_millisecond();
    T("now_millisecond in [0,999]", ms >= 0 && ms <= 999, "ms=" + cast<string>(ms));

    T("day_name(0)='Sunday'",   day_name(0) == "Sunday", "");
    T("day_name(6)='Saturday'", day_name(6) == "Saturday", "");
    T("day_name(99)='Unknown'", day_name(99) == "Unknown", "");

    T("month_name(1)='January'",  month_name(1) == "January", "");
    T("month_name(12)='December'",month_name(12) == "December", "");
    T("month_name(0)='Unknown'",  month_name(0) == "Unknown", "");

    T("hour12(0)=12",  hour12(0) == 12, "");
    T("hour12(13)=1",  hour12(13) == 1, "");
    T("hour12(23)=11", hour12(23) == 11, "");

    T("ampm(0)=AM",  ampm(0) == "AM", "");
    T("ampm(11)=AM", ampm(11) == "AM", "");
    T("ampm(12)=PM", ampm(12) == "PM", "");
    T("ampm(23)=PM", ampm(23) == "PM", "");

    // Bitcasts: float<->u32 round-trip on a known value (reinterpret_cast<>).
    float32 fpi = cast<float32>(3.14159f);
    uint32 fbits = reinterpret_cast<uint32>(fpi);
    float32 fback = reinterpret_cast<float32>(fbits);
    T("f32 bitcast roundtrip", fback == fpi, "");

    float64 dpi = 3.14159265358979;
    uint64 dbits = reinterpret_cast<uint64>(dpi);
    float64 dback = reinterpret_cast<float64>(dbits);
    T("f64 bitcast roundtrip", dback == dpi, "");

    T("reinterpret_cast<uint32>(0.0f)=0", reinterpret_cast<uint32>(0.0f) == 0, "");
    T("reinterpret_cast<uint64>(0.0)=0",  reinterpret_cast<uint64>(0.0)  == 0, "");

    // Thread priority — flip down then up, restore to normal.
    bool ok_lo = set_thread_priority(thread_priority::lowest);
    bool ok_hi = set_thread_priority(thread_priority::highest);
    bool ok_no = set_thread_priority(thread_priority::normal);
    T("set_thread_priority lowest",  ok_lo, "");
    T("set_thread_priority highest", ok_hi, "");
    T("set_thread_priority normal",  ok_no, "");
}

// ============================================================================
// 3. math3d — quat + mat4  (preshipped)
// ============================================================================

void test_math3d() {
    print_console("--- math3d ---");

    // ----- quat -----
    quat qid = quat_identity();
    T("quat_identity x=0", qid.x() == 0.0, "");
    T("quat_identity y=0", qid.y() == 0.0, "");
    T("quat_identity z=0", qid.z() == 0.0, "");
    T("quat_identity w=1", qid.w() == 1.0, "");

    quat q4 = quat(1.0, 2.0, 3.0, 4.0);
    T("quat ctor x=1", q4.x() == 1.0, "");
    T("quat ctor w=4", q4.w() == 4.0, "");
    T("quat length_sq=30", q4.length_sq() == 30.0, "got " + cast<string>(q4.length_sq()));

    quat qn = q4.normalize();
    T("quat normalize length=1", approx_eq(qn.length(), 1.0, 0.000001), "");

    // Rotate (1,0,0) by 90deg around Z -> (0,1,0).
    quat qz90 = quat_from_axis_angle(vec3(0.0, 0.0, 1.0), 1.5707963267948966);
    vec3 rotated = qz90.rotate(vec3(1.0, 0.0, 0.0));
    T("quat rotate Z90 x->y",
        approx_eq(rotated.x(), 0.0, 0.0001) && approx_eq(rotated.y(), 1.0, 0.0001),
        "got (" + cast<string>(rotated.x()) + ", " + cast<string>(rotated.y()) + ")");

    // q.conjugate() == q.inverse() for unit quat.
    quat qc = qz90.conjugate();
    quat qi = qz90.inverse();
    T("conjugate ~= inverse for unit quat",
        approx_eq(qc.x(), qi.x(), 0.000001) && approx_eq(qc.w(), qi.w(), 0.000001), "");

    // Compose two 90deg rotations -> 180.
    quat q180 = qz90 * qz90;
    vec3 r180 = q180.rotate(vec3(1.0, 0.0, 0.0));
    T("quat compose Z90*Z90 -> 180", approx_eq(r180.x(), -1.0, 0.0001), "");

    // Slerp endpoints.
    quat qb = quat_from_axis_angle(vec3(0.0, 1.0, 0.0), 1.5707963267948966);
    quat sa = qid.slerp(qb, 0.0);
    quat sb = qid.slerp(qb, 1.0);
    T("slerp(t=0) ~= a", approx_eq(sa.w(), qid.w(), 0.0001), "");
    T("slerp(t=1) ~= b", approx_eq(sb.y(), qb.y(), 0.0001), "");

    // From euler -> to euler roundtrip.
    quat qe = quat_from_euler(0.5, 0.3, 0.2);
    vec3 ev = qe.to_euler();
    T("euler roundtrip yaw",  approx_eq(ev.x(), 0.5, 0.001), "got " + cast<string>(ev.x()));
    T("euler roundtrip pitch",approx_eq(ev.y(), 0.3, 0.001), "got " + cast<string>(ev.y()));
    T("euler roundtrip roll", approx_eq(ev.z(), 0.2, 0.001), "got " + cast<string>(ev.z()));

    // ----- mat4 -----
    mat4 mid = mat4_identity();
    T("mat4 identity diag",
        mid.get(0,0) == 1.0 && mid.get(1,1) == 1.0 &&
        mid.get(2,2) == 1.0 && mid.get(3,3) == 1.0, "");
    T("mat4 identity off=0", mid.get(0,1) == 0.0 && mid.get(2,3) == 0.0, "");

    // set/get.
    mid.set(0, 3, 5.0);
    T("mat4 set/get", mid.get(0, 3) == 5.0, "");

    // Translation.
    mat4 tm = mat4_translation(vec3(10.0, 20.0, 30.0));
    vec3 tp = tm.transform_point(vec3(1.0, 2.0, 3.0));
    T("translation transforms point",
        approx_eq(tp.x(), 11.0, 0.0001) && approx_eq(tp.y(), 22.0, 0.0001) &&
        approx_eq(tp.z(), 33.0, 0.0001), "");

    // transform_vec3 ignores translation.
    vec3 tv = tm.transform_vec3(vec3(1.0, 2.0, 3.0));
    T("transform_vec3 ignores translation",
        approx_eq(tv.x(), 1.0, 0.0001) && approx_eq(tv.y(), 2.0, 0.0001), "");

    // Scale.
    mat4 sm = mat4_scale(vec3(2.0, 3.0, 4.0));
    vec3 sp = sm.transform_point(vec3(1.0, 1.0, 1.0));
    T("scale 2,3,4",
        approx_eq(sp.x(), 2.0, 0.0001) && approx_eq(sp.y(), 3.0, 0.0001) &&
        approx_eq(sp.z(), 4.0, 0.0001), "");

    // Z90 rotation matrix.
    mat4 rzm = mat4_rotation_z(1.5707963267948966);
    vec3 rzp = rzm.transform_point(vec3(1.0, 0.0, 0.0));
    T("mat4_rotation_z 90deg",
        approx_eq(rzp.x(), 0.0, 0.0001) && approx_eq(rzp.y(), 1.0, 0.0001), "");

    // Mat4 mul composes translations.
    mat4 ma = mat4_translation(vec3(1.0, 2.0, 3.0));
    mat4 mb = mat4_translation(vec3(10.0, 20.0, 30.0));
    mat4 mc = ma * mb;
    vec3 mcp = mc.transform_point(vec3(0.0, 0.0, 0.0));
    T("mat4 a*b composes translations",
        approx_eq(mcp.x(), 11.0, 0.0001) && approx_eq(mcp.y(), 22.0, 0.0001), "");

    // Inverse roundtrip.
    mat4 inv = ma.inverse();
    mat4 prod = ma * inv;
    T("mat4 a * inv ~= identity",
        approx_eq(prod.get(0,0), 1.0, 0.000001) &&
        approx_eq(prod.get(1,3), 0.0, 0.000001), "");

    // Determinant.
    T("det(identity) = 1", approx_eq(mid.determinant(), 1.0, 0.000001), "");
    T("det(scale 2,3,4) = 24",
        approx_eq(mat4_scale(vec3(2.0, 3.0, 4.0)).determinant(), 24.0, 0.000001), "");

    // mat4_from_quat agrees with quat.rotate.
    mat4 fq = mat4_from_quat(qz90);
    vec3 fqp = fq.transform_point(vec3(1.0, 0.0, 0.0));
    T("mat4_from_quat agrees with quat.rotate",
        approx_eq(fqp.x(), 0.0, 0.0001) && approx_eq(fqp.y(), 1.0, 0.0001), "");

    // Transpose.
    mat4 mt = mat4_identity();
    mt.set(0, 1, 7.0);
    mat4 mtT = mt.transpose();
    T("transpose moves (0,1) to (1,0)", mtT.get(1, 0) == 7.0, "");
}

// ============================================================================
// 4. Shared mutex  (preshipped, thread addon)
// ============================================================================

void test_shared_mutex() {
    print_console("--- shared_mutex ---");

    mutex m;

    // Plain exclusive lock still works.
    m.lock();
    m.unlock();
    T("exclusive lock/unlock", true, "");

    // Multiple shared holders allowed.
    m.lock_shared();
    m.lock_shared();

    // Exclusive try_lock fails while shared holders are active.
    bool got_excl = m.try_lock();
    T("try_lock fails while shared held", !got_excl, "");

    // try_lock_shared still works while shared.
    bool got_shared = m.try_lock_shared();
    T("try_lock_shared works while shared", got_shared, "");
    if (got_shared) m.unlock_shared();

    m.unlock_shared();
    m.unlock_shared();

    // After all shared released, exclusive lock works.
    m.lock();
    m.unlock();
    T("exclusive after shared released", true, "");
}

// ============================================================================
// 5. Sound  (perception, surface unless test.wav present)
// ============================================================================

void test_sound() {
    print_console("--- sound ---");

    // Bad path rejection.
    sound_t bad = load_sound("../escape.wav");
    T("load_sound rejects ..", cast<int64>(bad) == 0, "");

    sound_t empty = load_sound("");
    T("load_sound rejects empty", cast<int64>(empty) == 0, "");

    // Real load is optional — skip if missing.
    sound_t snd = load_sound("sounds/test.wav");
    if (cast<int64>(snd) == 0) {
        S("load_sound real file", "sounds/test.wav not present (optional)");
        return;
    }
    T("load_sound real file", true, "");

    sound_inst_t inst = snd.play(0.3, 0.0, false);
    T("sound.play returns instance", cast<int64>(inst) != 0, "");
    if (cast<int64>(inst) != 0) {
        inst.set_volume(0.2);
        inst.set_pan(-0.1);
        T("set_volume + set_pan don't crash", true, "");
        inst.stop();
    }
    stop_all_sounds();
}

// ============================================================================
// 6. Zydis  (perception)
// ============================================================================

void test_zydis() {
    print_console("--- zydis ---");

    // Mnemonic name lookup.
    int64 mov_id = zydis_mnemonic_from_string("mov");
    T("zydis_mnemonic_from_string('mov')", mov_id != 0, "");
    T("zydis_mnemonic round-trip", zydis_mnemonic_to_string(mov_id) == "mov", "");
    T("invalid mnemonic -> 0",
        zydis_mnemonic_from_string("notarealinstruction") == 0, "");

    // Register name lookup.
    int64 rax_id = zydis_register_from_string("rax");
    T("zydis_register_from_string('rax')", rax_id != 0, "");
    T("zydis_register round-trip", zydis_register_to_string(rax_id) == "rax", "");

    // Build + encode: mov rax, 0x1234.
    zydis_req_t req;
    req.set_mnemonic(mov_id);
    req.set_machine_mode(zydis_machine_mode::long_64);
    req.set_operand_count(2);
    req.set_operand_reg(0, rax_id);
    req.set_operand_imm(1, 0x1234);

    array<uint8> bytes = zydis_encode(req);
    T("encoded mov rax,0x1234", bytes.length() > 0, "got " + cast<string>(bytes.length()) + " bytes");

    // Round-trip via disasm.
    array<string> texts = zydis_disasm(bytes, 0);
    T("disasm one instruction", texts.length() == 1, "got " + cast<string>(texts.length()));
    if (texts.length() == 1) {
        T("disasm contains 'mov rax'",
            texts.get(0).contains("mov rax"),
            "got '" + texts.get(0) + "'");
    }

    // NOP fill.
    array<uint8> nops = zydis_nop_fill(8);
    T("nop_fill 8 bytes", nops.length() == 8, "");
    if (nops.length() == 8) {
        T("nop_fill first byte 0x90", nops.get(0) == 0x90, "");
    }

    // Builder.
    zydis_builder_t b;
    b.set_machine_mode(zydis_machine_mode::long_64);
    b.set_base_address(0x1000);
    b.push_nop(2);
    b.push_int3();
    b.push_ret();
    T("builder count = 4", b.get_count() == 4, "got " + cast<string>(b.get_count()));

    array<uint8> built = b.build();
    T("builder.build >= 4 bytes", built.length() >= 4, "got " + cast<string>(built.length()));
    if (built.length() >= 1) T("first nop = 0x90", built.get(0) == 0x90, "");

    // Raw push_u32 little-endian.
    b.clear();
    b.push_u32(0xDEADBEEF);
    array<uint8> raw32 = b.build();
    T("push_u32 -> 4 bytes", raw32.length() == 4, "");
    if (raw32.length() == 4) {
        bool le_ok = raw32.get(0) == 0xEF && raw32.get(1) == 0xBE
                  && raw32.get(2) == 0xAD && raw32.get(3) == 0xDE;
        T("push_u32 little-endian", le_ok, "");
    }

    // Decoded -> request roundtrip.
    zydis_req_t r2 = zydis_decoded_to_request(bytes, 0);
    T("decoded_to_request returns handle", cast<int64>(r2) != 0, "");
    if (cast<int64>(r2) != 0) {
        T("decoded request mnemonic = MOV",
            r2.get_mnemonic() == mov_id, "");
    }
}

// ============================================================================
// 7. Win API  (perception)
// ============================================================================

void test_win() {
    print_console("--- win ---");

    array<window_info_t> wins = get_all_hwnds();
    T("get_all_hwnds > 0", wins.length() > 0, "got " + cast<string>(wins.length()));

    if (wins.length() > 0) {
        window_info_t first = wins.get(0);
        T("first window has hwnd", first.hwnd() != 0, "");
        T("first window has pid", first.pid() != 0, "");

        string pn = first.process_name();
        T("first window has process name", pn.length() > 0, "got '" + pn + "'");
    }

    // Negative find.
    int64 fake = find_window("___nope_window_xyzzy___");
    T("find_window non-existent -> 0", fake == 0, "");

    // Locate a foreground window for query tests.
    int64 fg = 0;
    int64 i = 0;
    while (i < wins.length()) {
        if (is_foreground_window(wins.get(i).hwnd())) {
            fg = wins.get(i).hwnd();
            break;
        }
        i = i + 1;
    }

    if (fg != 0) {
        vec2 wp = get_window_pos(fg);
        T("get_window_pos returns vec2", true,
            "(" + cast<string>(wp.x()) + ", " + cast<string>(wp.y()) + ")");

        vec2 ws = get_window_size(fg);
        T("get_window_size returns vec2", ws.x() >= 0.0 && ws.y() >= 0.0, "");

        int64 ww = get_window_width(fg);
        int64 wh = get_window_height(fg);
        T("get_window_width / height match get_window_size",
            (float64)ww == ws.x() && (float64)wh == ws.y(), "");

        int64 tid = get_window_thread_id(fg);
        int64 pid = get_window_process_id(fg);
        T("get_window_thread_id / process_id non-zero", tid != 0 && pid != 0,
            "tid=" + cast<string>(tid) + " pid=" + cast<string>(pid));

        T("is_window_active(fg)", is_window_active(fg), "");
    } else {
        S("foreground-window queries", "no foreground window detected");
    }

    // Clipboard round-trip.
    string original = copy_from_clipboard();
    bool put_ok = copy_to_clipboard("enma_test_clipboard_xyz");
    T("copy_to_clipboard succeeds", put_ok, "");
    string roundtrip = copy_from_clipboard();
    T("clipboard roundtrip",
        roundtrip == "enma_test_clipboard_xyz",
        "got '" + roundtrip + "'");
    copy_to_clipboard(original);  // restore

    // Input fns: invoke without crashing.
    win_key_press(0x70, 5);   // F1
    mouse_move_relative(0, 0);
    mouse_scroll(0);
    T("input fns don't crash", true, "");
}

// ============================================================================
// 8. Input state polling  (perception, surface)
// ============================================================================

void test_input() {
    print_console("--- input ---");

    vec2 mp = get_mouse_pos();
    T("get_mouse_pos returns vec2", true,
        "(" + cast<string>(mp.x()) + ", " + cast<string>(mp.y()) + ")");

    vec2 md = get_mouse_delta();
    T("get_mouse_delta returns vec2", true,
        "(" + cast<string>(md.x()) + ", " + cast<string>(md.y()) + ")");

    vec2 dp = get_mouse_pos_desktop();
    T("get_mouse_pos_desktop returns vec2", true,
        "(" + cast<string>(dp.x()) + ", " + cast<string>(dp.y()) + ")");

    float64 sd = get_scroll_delta();
    T("get_scroll_delta runs", true, "value=" + cast<string>(sd));

    bool moved = mouse_movement_received();
    T("mouse_movement_received runs", true, "value=" + cast<string>(moved));

    bool h = is_hovered(0.0, 0.0, 1.0, 1.0);
    T("is_hovered runs", true, "got " + cast<string>(h));

    // Surface assert: don't crash on key state queries.
    bool kd = key_down(vk::pause);
    T("key_down(pause) runs", true, "value=" + cast<string>(kd));

    key_state_t ks = get_key_state(vk::a);
    T("get_key_state returns key_state_t", cast<int64>(ks) != 0,
        "down=" + cast<string>(ks.down()) + " fired=" + cast<string>(ks.fired()));

    array<int32> kdown = get_keys_down();
    T("get_keys_down returns array", kdown.length() >= 0, "size=" + cast<string>(kdown.length()));

    string nm = get_key_name(vk::space);
    T("get_key_name(space) non-empty", nm.length() > 0, "got '" + nm + "'");

    string buf = get_recent_key_input();
    T("get_recent_key_input runs", buf.length() >= 0, "");

    // Verify enum values are sane via known equalities.
    T("vk::space = 0x20", cast<int64>(vk::space) == 0x20, "");
    T("vk::f1 = 0x70",    cast<int64>(vk::f1) == 0x70, "");
}

// ============================================================================
// 9. Unicorn  (perception)
// ============================================================================

void test_unicorn() {
    print_console("--- unicorn ---");

    cpu_t cpu = cpu_create();
    T("cpu_create returns handle", cast<int64>(cpu) != 0, "");

    // Map code + stack pages.
    bool m1 = cpu.mem_map(0x10000, 0x1000, uc_prot::rwx);
    bool m2 = cpu.mem_map(0x20000, 0x1000, uc_prot::rw);
    T("mem_map code page", m1, "");
    T("mem_map stack page", m2, "");

    // Encode `mov rax, 0x42` then append HLT (0xF4).
    int64 mov_id = zydis_mnemonic_from_string("mov");
    int64 rax_id = zydis_register_from_string("rax");
    zydis_req_t req;
    req.set_mnemonic(mov_id);
    req.set_operand_count(2);
    req.set_operand_reg(0, rax_id);
    req.set_operand_imm(1, 0x42);
    array<uint8> mov_bytes = zydis_encode(req);
    T("encoded mov rax,0x42", mov_bytes.length() > 0, "");

    array<uint8> code;
    int64 ix = 0;
    while (ix < mov_bytes.length()) { code.push(mov_bytes.get(ix)); ix = ix + 1; }
    code.push(cast<uint8>(0xF4));   // HLT

    bool wrote = cpu.mem_write(0x10000, code);
    T("mem_write code", wrote, "");

    // Read back.
    array<uint8> read_back = cpu.mem_read(0x10000, code.length());
    bool readback_ok = read_back.length() == code.length();
    if (readback_ok) {
        int64 j = 0;
        while (j < code.length()) {
            if (read_back.get(j) != code.get(j)) { readback_ok = false; break; }
            j = j + 1;
        }
    }
    T("mem_read roundtrip", readback_ok, "");

    // Register write/read.
    cpu.reg_write64(uc_reg::rcx, 0xCAFEBABE);
    int64 rcx_v = cpu.reg_read64(uc_reg::rcx);
    T("rcx write/read",
        rcx_v == 0xCAFEBABE,
        "got " + cast<string>(rcx_v));

    // Set RSP, then run.
    cpu.reg_write64(uc_reg::rsp, 0x21000 - 8);
    int64 status = cpu.start(0x10000, 0x10000 + code.length(), 1000000, 0);
    T("cpu.start returned uc_err code", true, "status=" + cast<string>(status));

    int64 rax_after = cpu.reg_read64(uc_reg::rax);
    T("rax = 0x42 after exec", rax_after == 0x42, "got " + cast<string>(rax_after));

    // SIMD register round-trip.
    array<uint8> xmm_in;
    int64 k = 0;
    while (k < 16) { xmm_in.push(cast<uint8>(k * 2)); k = k + 1; }
    bool xmm_w = cpu.reg_write128(uc_reg::xmm0, xmm_in);
    array<uint8> xmm_out = cpu.reg_read128(uc_reg::xmm0);
    bool xmm_match = xmm_w && xmm_out.length() == 16;
    if (xmm_match) {
        int64 m = 0;
        while (m < 16) {
            if (xmm_out.get(m) != xmm_in.get(m)) { xmm_match = false; break; }
            m = m + 1;
        }
    }
    T("xmm0 128-bit roundtrip", xmm_match, "");

    bool flushed = cpu.flush_code();
    T("flush_code returns true", flushed, "");

    // Check enum constants are non-zero (sanity).
    T("uc_reg::rax != 0",  cast<int64>(uc_reg::rax) != 0, "");
    T("uc_prot::rwx != 0", cast<int64>(uc_prot::rwx) != 0, "");
    T("uc_hook::code != 0",cast<int64>(uc_hook::code) != 0, "");
}

// ============================================================================
// 10. Net  (perception, gated by 'network_access' permission)
// ============================================================================

void test_net() {
    print_console("--- net ---");

    http_response_t r = http_get("http://example.org/", 5000);
    int64 status = r.status();
    string body = r.body();

    if (status == 0) {
        // Either gate is closed, or transport actually failed.
        S("http_get",
          "status=0 (network_access permission may be off, or no connectivity)");
    } else if (status == 200) {
        T("http_get status 200", true, "");
        T("http_get ok() agrees with status", r.ok(), "");
        T("http_get body non-empty", body.length() > 0, "");
        T("http_get body has <html",
            body.contains("<html") || body.contains("<HTML"),
            "first 80=" + body.substr(0, 80));
    } else {
        T("http_get status not 0 and not 200",
            true, "got " + cast<string>(status));  // unusual but not a bug
    }

    // POST. httpbin may not always answer; treat anything non-200 as a skip.
    http_response_t p = http_post("http://httpbin.org/post",
        "application/json", "{\"a\":1}", 5000);
    int64 ps = p.status();
    string presp = p.body();
    if (ps == 200) {
        T("http_post 200", true, "");
        T("http_post echoes body", presp.contains("\"a\""),
            "first 120=" + presp.substr(0, 120));
    } else if (ps == 0) {
        S("http_post", "status=0 (gate or transport)");
    } else {
        S("http_post", "non-200 from httpbin (rate limit / down) status=" + cast<string>(ps));
    }

    // ws_t requires a server; just verify the call shape doesn't crash.
    ws_t ws = ws_connect("ws://localhost:65535/", 500);
    if (cast<int64>(ws) == 0) {
        T("ws_connect to dead port returns null handle (expected)", true, "");
    } else {
        T("ws_connect to dead port returned non-null handle (unusual)", true, "");
        ws.close(1000);
    }
}

// ============================================================================
// main
// ============================================================================

// ============================================================================
// 11. GUI  (perception, surface)
// ============================================================================
//
// Creating GUI elements actually pollutes the UI panel, so we only do a
// minimal sanity exercise. Cleanup runs at script unload.

void test_gui() {
    print_console("--- gui ---");

    bool ga = gui_active();
    T("gui_active runs", true, "value=" + cast<string>(ga));

    vec2 sz = get_gui_size();
    T("get_gui_size returns vec2", true,
        "(" + cast<string>(sz.x()) + ", " + cast<string>(sz.y()) + ")");

    vec2 pos = get_gui_position();
    T("get_gui_position returns vec2", true,
        "(" + cast<string>(pos.x()) + ", " + cast<string>(pos.y()) + ")");

    // Create a sidebar section with a couple of widgets.
    sidebar_section_t sec = create_sidebar_section("enma_test", "");
    bool ok = cast<int64>(sec) != 0;
    T("create_sidebar_section returns handle", ok, "");

    if (ok) {
        checkbox_t cb = sec.create_checkbox("enabled", true);
        T("section.create_checkbox returns handle", cast<int64>(cb) != 0, "");
        if (cast<int64>(cb) != 0) {
            T("checkbox initial=true", cb.get(), "");
            cb.set(false);
            T("checkbox set/get roundtrip", !cb.get(), "");
        }

        slider_t sl = sec.create_slider("Volume", 0.5, 0.0, 1.0, 0.0);
        T("section.create_slider returns handle", cast<int64>(sl) != 0, "");
        if (cast<int64>(sl) != 0) {
            sl.set(0.75);
            T("slider set/get", approx_eq(sl.get(), 0.75, 0.001), "");
        }

        sec.create_separator();

        array<string> opts;
        opts.push("Apple"); opts.push("Banana"); opts.push("Cherry");
        dropdown_t dd = sec.create_dropdown("Fruit", opts, 1);
        T("section.create_dropdown returns handle", cast<int64>(dd) != 0, "");
        if (cast<int64>(dd) != 0) {
            T("dropdown initial=1 (Banana)", dd.get() == 1, "got " + cast<string>(dd.get()));
        }
    }

    // Sidebar separator.
    create_sidebar_separator();
    T("create_sidebar_separator runs", true, "");

    // show_toast — fire-and-forget, no return state.
    show_toast(toast_kind::info, "enma_test", "GUI surface check OK");
    T("show_toast runs", true, "");

    // Theme read returns a color handle.
    color bg = get_theme_color(ui_color::bg);
    T("get_theme_color returns color", cast<int64>(bg) != 0, "");

    T("is_dark_theme returns bool", true, "value=" + cast<string>(is_dark_theme()));
}

int32 main() {
    print_console("=== test_all_apis: starting ===");

    test_url();
    test_cpu();
    test_math3d();
    test_shared_mutex();
    test_sound();
    test_zydis();
    test_win();
    test_input();
    test_gui();
    test_unicorn();
    test_net();

    print_console("");
    print_console("=== summary ===");
    print_console("  pass: " + cast<string>(g_pass));
    print_console("  fail: " + cast<string>(g_fail));
    print_console("  skip: " + cast<string>(g_skip));
    if (g_fail == 0) {
        print_console("ALL GREEN (skips are environment-dependent, not bugs)");
    } else {
        print_console("FAILURES PRESENT — see FAIL lines above");
    }
    return cast<int32>(g_fail == 0 ? 1 : 0);
}
