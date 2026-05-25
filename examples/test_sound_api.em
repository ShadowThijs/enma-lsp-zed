// =============================================================================
// Sound API smoke test — abs.wav playback
//
// Loads abs.wav from My Games and exercises the full play surface:
//   load_sound -> sound_t
//   sound_t.play(volume, pan, loop) -> sound_inst_t
//   sound_inst_t.is_playing / set_volume / set_pan / stop
//   stop_all_sounds()
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

    print_console("=== sound API smoke test (abs.wav) ===");

    section("load");

    sound_t snd = load_sound("abs.wav");
    check("load_sound('abs.wav') returns non-zero handle", cast<int64>(snd) != 0);
    if (cast<int64>(snd) == 0) {
        print_console("[abort] abs.wav failed to load; bail");
        unregister_routine(g_handle);
        return;
    }

    section("play");

    sound_inst_t inst = snd.play(0.7, 0.0, false);
    check("snd.play(0.7, 0.0, false) returns non-zero instance",
          cast<int64>(inst) != 0);

    if (cast<int64>(inst) != 0) {
        check("is_playing() true immediately after play()", inst.is_playing());

        section("live volume / pan adjustments");

        inst.set_volume(0.3);
        inst.set_pan(-0.7);
        sleep_ms(150);
        inst.set_pan(0.7);
        sleep_ms(150);
        inst.set_pan(0.0);
        inst.set_volume(0.7);
        check("live set_volume / set_pan survive without fault", true);

        section("stop");

        inst.stop();
        check("inst.stop() survives", true);
    }

    section("loop play + stop_all_sounds");

    sound_inst_t loop_inst = snd.play(0.3, 0.0, true);
    check("loop play returns non-zero instance", cast<int64>(loop_inst) != 0);
    if (cast<int64>(loop_inst) != 0) {
        check("loop instance is_playing()", loop_inst.is_playing());
        sleep_ms(500);
        stop_all_sounds();
        check("stop_all_sounds() survives", true);
    }

    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked - resetting and re-firing routine");
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
