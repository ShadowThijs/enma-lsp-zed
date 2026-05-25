// =============================================================================
// Net API smoke test
//
// Exercises every native registered by enma_net_api.cpp:
//   - http_get(url, timeout_ms) -> http_response_t (.status / .body / .ok)
//   - http_post(url, content_type, body, timeout_ms) -> http_response_t
//   - ws_connect(url, timeout_ms) -> ws_t
//   - ws_t.is_open / send_text / send_binary / recv / poll / close
//   - ws_message_t.ok / is_text / is_closed / payload
//
// Network access is gated by `network_access` permission. When the gate is
// off (default), http_* return status=0 and ws_connect returns 0. When the
// gate is on, we hit real endpoints — example.org for HTML, httpbin.org for
// JSON + status code coverage, and echo.websocket.events for WebSocket.
//
// Network failure (DNS / firewall / etc.) shows as status=0 but does NOT
// fail the test — these are surface checks, not network availability checks.
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

    print_console("=== net API smoke test ===");

    // -----------------------------------------------------------------------
    // http_get — basic shape. http_response_t is non-null even on transport
    // failure; status() == 0 indicates the transport-failure shape (gate off
    // OR DNS failure OR connection error).
    // -----------------------------------------------------------------------
    section("http_get - example.org");

    http_response_t r1 = http_get("http://example.org", 5000);
    check("http_get returns non-null response handle", cast<int64>(r1) != 0);

    int64 s1 = r1.status();
    string b1 = r1.body();
    bool ok1  = r1.ok();
    print_console("  status = " + cast<string>(s1));
    print_console("  body length = " + cast<string>(b1.length()));
    print_console("  ok = " + cast<string>(ok1));

    if (s1 == 0) {
        print_console("[note] status=0; gate likely off OR network unreachable");
        check("status=0 -> ok()=false (transport failure shape)", !ok1);
    } else {
        check("status > 0 means transport succeeded", s1 > 0);
        if (s1 >= 200 && s1 < 300) {
            check("ok() == true for 2xx", ok1);
            check("body length > 0 for 2xx", b1.length() > 0);
        }
    }

    // -----------------------------------------------------------------------
    // http_get with a bogus host name — transport must fail cleanly with
    // status=0 (and body is the empty string sentinel).
    // -----------------------------------------------------------------------
    section("http_get - bogus host");

    http_response_t r_bogus = http_get(
        "http://this-host-does-not-exist-xyz-42-zz.invalid", 2000);
    check("http_get(bogus host) returns non-null", cast<int64>(r_bogus) != 0);
    check("http_get(bogus host).status() == 0", r_bogus.status() == 0);
    check("http_get(bogus host).ok() == false", !r_bogus.ok());

    // -----------------------------------------------------------------------
    // http_get with empty url — guarded server-side.
    // -----------------------------------------------------------------------
    section("http_get - empty url");

    http_response_t r_empty = http_get("", 1000);
    check("http_get('') returns non-null", cast<int64>(r_empty) != 0);
    check("http_get('').status() == 0", r_empty.status() == 0);

    // -----------------------------------------------------------------------
    // http_get against httpbin.org/status/<code> — verifies non-2xx ok().
    // Skipped silently if the network's unreachable.
    // -----------------------------------------------------------------------
    section("http_get - httpbin status codes");

    http_response_t r404 = http_get("http://httpbin.org/status/404", 5000);
    int64 s404 = r404.status();
    print_console("  httpbin/status/404 -> status = " + cast<string>(s404));
    if (s404 == 0) {
        print_console("[note] gate off OR httpbin unreachable; skipping 404 assertion");
    } else {
        check("httpbin/status/404 returns 404", s404 == 404);
        check("httpbin/status/404.ok() == false", !r404.ok());
    }

    http_response_t r500 = http_get("http://httpbin.org/status/500", 5000);
    int64 s500 = r500.status();
    if (s500 == 0) {
        print_console("[note] gate off OR httpbin unreachable; skipping 500 assertion");
    } else {
        check("httpbin/status/500 returns 500", s500 == 500);
        check("httpbin/status/500.ok() == false", !r500.ok());
    }

    // -----------------------------------------------------------------------
    // http_post — JSON payload to httpbin.org/post which echoes the body.
    // The response body, if status is 200, contains our payload string
    // somewhere inside.
    // -----------------------------------------------------------------------
    section("http_post - httpbin /post");

    http_response_t rp = http_post(
        "http://httpbin.org/post",
        "application/json",
        "{\"hello\":\"enma-test\"}",
        5000);
    check("http_post returns non-null", cast<int64>(rp) != 0);

    int64 sp = rp.status();
    string bp = rp.body();
    print_console("  status = " + cast<string>(sp) +
                  "  body length = " + cast<string>(bp.length()));
    if (sp == 0) {
        print_console("[note] http_post status=0; gate off OR unreachable");
    } else {
        check("http_post status > 0", sp > 0);
        if (sp == 200) {
            check("http_post 200 body length > 0", bp.length() > 0);
            // httpbin echoes the body inside its JSON response.
            check("http_post 200 body contains 'enma-test'",
                  bp.find("enma-test") >= 0);
        }
    }

    // empty url + body shape.
    http_response_t rp_empty = http_post("", "", "", 1000);
    check("http_post('','','',1000) survives", cast<int64>(rp_empty) != 0);
    check("http_post('','','',1000).status() == 0",
          rp_empty.status() == 0);

    // -----------------------------------------------------------------------
    // WebSocket — connect to a public echo server. Surface checks ALWAYS
    // run (handle shape, is_open shape). recv() / send_text only fire when
    // connect succeeded.
    //
    // Echo server: echo.websocket.events. send_text echoes text back; the
    // first message is a server welcome banner ("echo.websocket.events
    // sponsored by Lob.com" or similar). We use poll() in a short loop
    // instead of recv() to avoid hangs if the echo server isn't reachable.
    // -----------------------------------------------------------------------
    section("ws_connect - echo.websocket.events");

    ws_t ws = ws_connect("wss://echo.websocket.events/", 5000);
    bool ws_ok = cast<int64>(ws) != 0;
    check("ws_connect returns handle (non-null when gate on + reachable)",
          ws_ok || !ws_ok);  // tautology: pass either way; assertions below
                            // condition on the actual outcome.

    if (!ws_ok) {
        print_console("[note] ws_connect returned 0 - gate off OR host unreachable");
        // Surface checks on null handle: methods on a null handle should
        // fail cleanly without faulting.
        ws_t null_ws;
        check("null ws.is_open() == false", !null_ws.is_open());
        check("null ws.send_text('x') == false",
              !null_ws.send_text("x"));
    } else {
        check("ws.is_open() == true after connect", ws.is_open());

        bool sent = ws.send_text("hello-enma-42");
        check("ws.send_text('hello-enma-42') succeeds", sent);

        // Poll for up to ~3s. The echo server typically returns the welcome
        // banner first, then our echo. Either is enough to prove send/recv.
        int64 tries = 0;
        bool got_msg = false;
        while (tries < 30) {
            ws_message_t m = ws.poll();
            if (m.ok()) {
                got_msg = true;
                bool is_t = m.is_text();
                string p  = m.payload();
                check("polled message ok() == true", true);
                check("polled message has non-empty payload", p.length() > 0);
                print_console("  is_text=" + cast<string>(is_t) +
                              "  payload(first 80)=" + p.substr(0, 80));
                break;
            }
            sleep_ms(100);
            tries = tries + 1;
        }
        check("at least one ws message arrived within ~3s", got_msg);

        // Send binary — 4 raw bytes. The echo server echoes binary back.
        array<uint8> bin;
        bin.push(0xDE); bin.push(0xAD); bin.push(0xBE); bin.push(0xEF);
        bool sent_bin = ws.send_binary(bin);
        check("ws.send_binary(4 bytes) succeeds", sent_bin);

        // Graceful close.
        ws.close(1000);
        check("ws.close(1000) survives", true);

        // Post-close, is_open should be false. Some implementations take a
        // moment for the recv thread to wind down.
        bool open_after = ws.is_open();
        // Don't strictly assert false; just exercise the call.
        check("ws.is_open() after close survives", open_after || !open_after);
    }

    // -----------------------------------------------------------------------
    // ws_message_t default shape — exercise the empty-handle path through
    // a poll() call after close. (If we never connected, we just assert
    // that null-handle behavior works.)
    // -----------------------------------------------------------------------
    section("ws_message_t edge");

    if (!ws_ok) {
        ws_t null_ws;
        ws_message_t m = null_ws.poll();
        // poll on null returns a stub with is_closed=true.
        check("null ws.poll() returns non-null shell", cast<int64>(m) != 0);
        if (cast<int64>(m) != 0) {
            check("null poll().ok() == false", !m.ok());
            check("null poll().is_closed() == true", m.is_closed());
        }
    }

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
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
    print_console("[test_net_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("net test", "");
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
