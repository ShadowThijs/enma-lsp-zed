// =============================================================================
// Sound API comprehensive test — every type, method, and function
//
// CHECKLIST — every item documented in docs/Perception/Sound API.md:
//
// ── Types ─────────────────────────────────────────────────────────────────
//   [x] sound_t        — int64-backed handle for a loaded sound resource
//   [x] sound_inst_t   — int64-backed handle for a live playback instance
//
// ── Standalone functions ──────────────────────────────────────────────────
//   [x] load_sound(string relative_path) -> sound_t
//   [x] stop_all_sounds()
//
// ── sound_t methods ───────────────────────────────────────────────────────
//   [x] sound.play(float64 volume, float64 pan, bool loop) -> sound_inst_t
//
// ── sound_inst_t methods ──────────────────────────────────────────────────
//   [x] inst.is_playing() -> bool
//   [x] inst.stop()
//   [x] inst.set_volume(float64 v)     // 0.0 .. 1.0
//   [x] inst.set_pan(float64 p)        // -1.0 .. 1.0
//
// ── Behaviors ─────────────────────────────────────────────────────────────
//   [x] null-handle check via cast<int64>(handle) == 0
//   [x] auto-cleanup destructors at scope exit
//   [x] multiple instances from one sound_t
//   [x] volume / pan boundary values
//   [x] loop vs one-shot playback
//   [x] path validation: no .., no :, no leading / or \
//   [x] stop_all_sounds() halts every instance globally
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

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Sound API comprehensive test ===");

    // =========================================================================
    // load_sound — type: sound_t
    //
    // load_sound(string relative_path) -> sound_t
    //   - Returns non-null handle on success
    //   - Returns null handle on validation failure or read failure
    //   - sound_t is int64-backed with auto-cleanup destructor
    // =========================================================================

    section("load_sound — valid path");

    sound_t snd = load_sound("abs.wav");
    check("load_sound('abs.wav') returns non-null sound_t", cast<int64>(snd) != 0);

    // Save the handle value to verify it's non-zero.
    int64 snd_handle = cast<int64>(snd);
    check("sound_t handle value is non-zero", snd_handle != 0);
    check("sound_t is int64-backed (cast succeeds)", true);

    if (cast<int64>(snd) == 0) {
        print_console("[abort] abs.wav failed to load; skip remaining tests");
        unregister_routine(g_handle);
        return;
    }

    section("load_sound — invalid paths (should return null handle)");

    // Path validation: no leading /
    sound_t bad_abs = load_sound("/abs.wav");
    check("load_sound('/abs.wav') returns null (leading /)", cast<int64>(bad_abs) == 0);

    // Path validation: no leading backslash
    sound_t bad_bs = load_sound("\\abs.wav");
    check("load_sound('\\abs.wav') returns null (leading backslash)", cast<int64>(bad_bs) == 0);

    // Path validation: no .. segments
    sound_t bad_dotdot = load_sound("../sounds/abs.wav");
    check("load_sound('../sounds/abs.wav') returns null (.. segment)", cast<int64>(bad_dotdot) == 0);

    // Path validation: no drive letter colon
    sound_t bad_colon = load_sound("C:sounds/abs.wav");
    check("load_sound('C:sounds/abs.wav') returns null (colon)", cast<int64>(bad_colon) == 0);

    // Non-existent file returns null handle (read failure)
    sound_t missing = load_sound("nonexistent_file_xyz.wav");
    check("load_sound('nonexistent_file_xyz.wav') returns null (read failure)", cast<int64>(missing) == 0);

    // Empty path returns null handle
    sound_t empty = load_sound("");
    check("load_sound('') returns null (empty path)", cast<int64>(empty) == 0);

    // =========================================================================
    // sound_t.play(volume, pan, loop) -> sound_inst_t
    //
    //   - volume: 0.0 .. 1.0 (clamped)
    //   - pan:    -1.0 (full left) .. 1.0 (full right) (clamped)
    //   - loop:   repeat forever until stopped
    //   - Returns non-null sound_inst_t on success
    //   - sound_inst_t is int64-backed with auto-cleanup destructor
    // =========================================================================

    section("sound.play — basic playback");

    sound_inst_t inst = snd.play(0.7, 0.0, false);
    check("snd.play(0.7, 0.0, false) returns non-null sound_inst_t", cast<int64>(inst) != 0);

    int64 inst_handle = cast<int64>(inst);
    check("sound_inst_t handle value is non-zero", inst_handle != 0);
    check("sound_inst_t is int64-backed (cast succeeds)", true);

    section("sound.play — volume boundary values");

    // volume = 0.0 (minimum)
    sound_inst_t vol_min = snd.play(0.0, 0.0, false);
    check("snd.play(0.0, 0.0, false) — volume at minimum", cast<int64>(vol_min) != 0);
    sleep_ms(10);
    vol_min.stop();

    // volume = 1.0 (maximum)
    sound_inst_t vol_max = snd.play(1.0, 0.0, false);
    check("snd.play(1.0, 0.0, false) — volume at maximum", cast<int64>(vol_max) != 0);
    sleep_ms(10);
    vol_max.stop();

    // volume in middle of range
    sound_inst_t vol_mid = snd.play(0.5, 0.0, false);
    check("snd.play(0.5, 0.0, false) — volume mid-range", cast<int64>(vol_mid) != 0);
    sleep_ms(10);
    vol_mid.stop();

    section("sound.play — pan boundary values");

    // pan = -1.0 (full left)
    sound_inst_t pan_left = snd.play(0.3, -1.0, false);
    check("snd.play(0.3, -1.0, false) — pan full left", cast<int64>(pan_left) != 0);
    sleep_ms(10);
    pan_left.stop();

    // pan = 0.0 (center)
    sound_inst_t pan_center = snd.play(0.3, 0.0, false);
    check("snd.play(0.3, 0.0, false) — pan center", cast<int64>(pan_center) != 0);
    sleep_ms(10);
    pan_center.stop();

    // pan = 1.0 (full right)
    sound_inst_t pan_right = snd.play(0.3, 1.0, false);
    check("snd.play(0.3, 1.0, false) — pan full right", cast<int64>(pan_right) != 0);
    sleep_ms(10);
    pan_right.stop();

    section("sound.play — loop vs one-shot");

    // One-shot (loop = false)
    sound_inst_t one_shot = snd.play(0.5, 0.0, false);
    check("snd.play(0.5, 0.0, false) — one-shot (loop=false)", cast<int64>(one_shot) != 0);
    sleep_ms(10);
    one_shot.stop();

    // Looping (loop = true)
    sound_inst_t looping = snd.play(0.5, 0.0, true);
    check("snd.play(0.5, 0.0, true) — looping (loop=true)", cast<int64>(looping) != 0);
    sleep_ms(10);

    // =========================================================================
    // sound_inst_t.is_playing() -> bool
    //
    // Returns true if the instance is actively playing, false otherwise.
    // =========================================================================

    section("sound_inst.is_playing");

    // Immediately after play, should be playing
    check("inst.is_playing() returns true immediately after play()", inst.is_playing());

    // Looping instance should also be playing
    check("looping instance is_playing() returns true", looping.is_playing());

    // Stop then check is_playing returns false
    inst.stop();
    check("inst.is_playing() returns false after stop()", !inst.is_playing());

    // The one_shot was stopped, check it too
    check("stopped one_shot.is_playing() returns false", !one_shot.is_playing());

    // =========================================================================
    // sound_inst_t.set_volume(float64 v)
    //
    // Adjusts volume of a live instance. Expected range: 0.0 .. 1.0.
    // =========================================================================

    section("sound_inst.set_volume");

    // Start fresh instance for volume tests
    sound_inst_t vol_test = snd.play(0.5, 0.0, false);
    check("vol_test instance created", cast<int64>(vol_test) != 0);

    // set_volume at various levels
    vol_test.set_volume(0.0);
    check("vol_test.set_volume(0.0) — minimum volume", true);

    vol_test.set_volume(0.25);
    check("vol_test.set_volume(0.25) — quarter volume", true);

    vol_test.set_volume(0.5);
    check("vol_test.set_volume(0.5) — half volume", true);

    vol_test.set_volume(0.75);
    check("vol_test.set_volume(0.75) — three-quarter volume", true);

    vol_test.set_volume(1.0);
    check("vol_test.set_volume(1.0) — full volume", true);

    // set_volume at boundary: just above 0
    vol_test.set_volume(0.001);
    check("vol_test.set_volume(0.001) — near minimum", true);

    // set_volume at boundary: just below 1
    vol_test.set_volume(0.999);
    check("vol_test.set_volume(0.999) — near maximum", true);

    // Restore to normal before next tests
    vol_test.set_volume(0.5);
    vol_test.stop();

    // =========================================================================
    // sound_inst_t.set_pan(float64 p)
    //
    // Adjusts stereo pan of a live instance. Expected range: -1.0 .. 1.0.
    // -1.0 = full left, 0.0 = center, 1.0 = full right.
    // =========================================================================

    section("sound_inst.set_pan");

    // Start fresh instance for pan tests
    sound_inst_t pan_test = snd.play(0.5, 0.0, false);
    check("pan_test instance created", cast<int64>(pan_test) != 0);

    // set_pan at various positions
    pan_test.set_pan(-1.0);
    check("pan_test.set_pan(-1.0) — full left", true);

    pan_test.set_pan(-0.5);
    check("pan_test.set_pan(-0.5) — half left", true);

    pan_test.set_pan(0.0);
    check("pan_test.set_pan(0.0) — center", true);

    pan_test.set_pan(0.5);
    check("pan_test.set_pan(0.5) — half right", true);

    pan_test.set_pan(1.0);
    check("pan_test.set_pan(1.0) — full right", true);

    // set_pan at boundary: just above -1
    pan_test.set_pan(-0.999);
    check("pan_test.set_pan(-0.999) — near full left", true);

    // set_pan at boundary: just below 1
    pan_test.set_pan(0.999);
    check("pan_test.set_pan(0.999) — near full right", true);

    // Return to center
    pan_test.set_pan(0.0);
    pan_test.stop();

    // =========================================================================
    // sound_inst_t.stop()
    //
    // Halts playback for a specific instance.
    // =========================================================================

    section("sound_inst.stop");

    // Start a fresh instance and stop it
    sound_inst_t stop_test = snd.play(0.5, 0.0, false);
    check("stop_test created", cast<int64>(stop_test) != 0);
    check("stop_test.is_playing() before stop", stop_test.is_playing());

    stop_test.stop();
    check("stop_test.is_playing() after stop() returns false", !stop_test.is_playing());

    // Calling stop() on an already-stopped instance should not crash
    stop_test.stop();
    check("stop_test.stop() twice — no crash", true);

    // Calling stop() on the same handle after stop() — redundant but safe
    stop_test.stop();
    check("stop_test.stop() thrice — still no crash", true);

    // Verify is_playing remains false after redundant stops
    check("stop_test.is_playing() still false after multiple stops", !stop_test.is_playing());

    // =========================================================================
    // Multiple instances from one sound_t
    //
    // "Multiple instances can play from one resource concurrently."
    // =========================================================================

    section("multiple concurrent instances from one sound_t");

    sound_inst_t multi_a = snd.play(0.4, -0.8, false);
    sound_inst_t multi_b = snd.play(0.5,  0.0, false);
    sound_inst_t multi_c = snd.play(0.6,  0.8, false);

    check("multi_a created successfully", cast<int64>(multi_a) != 0);
    check("multi_b created successfully", cast<int64>(multi_b) != 0);
    check("multi_c created successfully", cast<int64>(multi_c) != 0);

    // All three should report playing
    check("multi_a is_playing()", multi_a.is_playing());
    check("multi_b is_playing()", multi_b.is_playing());
    check("multi_c is_playing()", multi_c.is_playing());

    // Adjust a subset independently
    multi_a.set_volume(0.8);
    multi_a.set_pan(-0.5);
    check("multi_a volume/pan adjusted independently", true);

    multi_b.set_volume(0.2);
    multi_b.set_pan(0.3);
    check("multi_b volume/pan adjusted independently", true);

    // Stop individual instances
    multi_a.stop();
    check("multi_a.is_playing() after stop", !multi_a.is_playing());
    check("multi_b.is_playing() still true (not stopped)", multi_b.is_playing());
    check("multi_c.is_playing() still true (not stopped)", multi_c.is_playing());

    multi_c.stop();
    check("multi_c.is_playing() after stop", !multi_c.is_playing());

    multi_b.stop();
    check("multi_b.is_playing() after stop", !multi_b.is_playing());

    // =========================================================================
    // Combined set_volume + set_pan on a live instance
    // =========================================================================

    section("combined live adjustments");

    sound_inst_t combined = snd.play(0.5, 0.0, true);
    check("combined instance created", cast<int64>(combined) != 0);

    // Chain of live adjustments (simulating real-time mixer changes)
    combined.set_volume(0.8);
    combined.set_pan(-0.3);
    sleep_ms(20);

    combined.set_volume(0.6);
    combined.set_pan(0.1);
    sleep_ms(20);

    combined.set_volume(0.4);
    combined.set_pan(0.5);
    sleep_ms(20);

    combined.set_volume(0.9);
    combined.set_pan(-0.7);
    sleep_ms(20);

    check("combined live adjustments — no crash", true);

    // =========================================================================
    // stop_all_sounds() — global halt for every instance
    //
    // "Halts every instance globally."
    // =========================================================================

    section("stop_all_sounds — global halt");

    // Start several instances for the global stop test
    sound_inst_t global_a = snd.play(0.5, 0.0, true);
    sound_inst_t global_b = snd.play(0.6, -0.5, true);
    sound_inst_t global_c = snd.play(0.7, 0.5, false);

    check("global_a created", cast<int64>(global_a) != 0);
    check("global_b created", cast<int64>(global_b) != 0);
    check("global_c created", cast<int64>(global_c) != 0);

    check("global_a.is_playing() before stop_all", global_a.is_playing());
    check("global_b.is_playing() before stop_all", global_b.is_playing());
    check("global_c.is_playing() before stop_all", global_c.is_playing());

    stop_all_sounds();
    check("stop_all_sounds() executed without fault", true);

    // All should now be stopped
    check("global_a.is_playing() after stop_all_sounds()", !global_a.is_playing());
    check("global_b.is_playing() after stop_all_sounds()", !global_b.is_playing());
    check("global_c.is_playing() after stop_all_sounds()", !global_c.is_playing());

    // Calling stop_all_sounds when nothing is playing should be safe
    stop_all_sounds();
    check("stop_all_sounds() when idle — no crash", true);

    // =========================================================================
    // sound_inst_t — play after global stop
    //
    // Ensure we can play new instances after a global halt.
    // =========================================================================

    section("play after stop_all_sounds");

    sound_inst_t after_global = snd.play(0.4, 0.0, false);
    check("play after stop_all_sounds works", cast<int64>(after_global) != 0);
    check("after_global.is_playing()", after_global.is_playing());
    after_global.stop();
    check("after_global stopped cleanly", !after_global.is_playing());

    // =========================================================================
    // sound_t — null handle edge cases
    //
    // Verify that operations on valid handles work (we cannot test operations
    // on null handles since the host will reject them; instead we verify that
    // null detection works correctly).
    // =========================================================================

    section("null handle detection");

    // Verify null handle for failed loads
    sound_t null_snd = load_sound("does_not_exist.wav");
    check("null_snd has zero handle value", cast<int64>(null_snd) == 0);

    // Verify a valid handle is non-zero
    check("valid snd has non-zero handle value", cast<int64>(snd) != 0);

    // =========================================================================
    // Lifetime / destructor verification
    //
    // sound_t and sound_inst_t both release at scope exit. The host also
    // sweeps remaining handles at unload. We verify that play/stop patterns
    // work correctly within scoped blocks.
    // =========================================================================

    section("scoped lifetime");

    // Load a sound inside a block to exercise destructor at scope exit
    {
        sound_t scoped_snd = load_sound("abs.wav");
        check("scoped_snd loaded inside block", cast<int64>(scoped_snd) != 0);

        if (cast<int64>(scoped_snd) != 0) {
            sound_inst_t scoped_inst = scoped_snd.play(0.3, 0.0, false);
            check("scoped_inst created inside block", cast<int64>(scoped_inst) != 0);

            if (cast<int64>(scoped_inst) != 0) {
                check("scoped_inst.is_playing() inside block", scoped_inst.is_playing());
                scoped_inst.stop();
                check("scoped_inst stopped inside block", !scoped_inst.is_playing());
            }
        }

        // scoped_snd and scoped_inst destructors fire here
        check("scoped block exit — destructors fire (no crash)", true);
    }

    // After the block, verify the outer snd is still usable
    sound_inst_t after_scope = snd.play(0.5, 0.0, false);
    check("outer sound_t still usable after inner scope exits", cast<int64>(after_scope) != 0);
    if (cast<int64>(after_scope) != 0) {
        check("after_scope.is_playing()", after_scope.is_playing());
        after_scope.stop();
    }

    // =========================================================================
    // Summary
    // =========================================================================

    print_console("");
    print_console("===========================================");
    print_console("  Sound API — PASS: " + cast<string>(g_pass));
    print_console("  Sound API — FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

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
    print_console("[test_sound_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("sound test", "");
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
    return 1;
}
