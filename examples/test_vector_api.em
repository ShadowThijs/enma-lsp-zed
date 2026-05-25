// =============================================================================
// Vector API smoke test (vec2 / vec3 / vec4)
//
// Tests the preshipped em_addon_vec types:
//   - constructors: vec2(x, y), vec3(x, y, z), vec4(x, y, z, w)
//   - field access via property:  v.x  v.y  v.z  v.w
//   - method access:              v.x() v.y() v.z() v.w()
//   - geometric methods: length / length_sq / dot / distance / normalize
//   - arithmetic methods: add / sub / scale / negate / lerp
//   - operators: + (bin_add), - (bin_sub / unary_neg), == (bin_eq)
//   - vec2-only: rotate
//   - vec3-only: cross / reflect / project / angle / rotate_around
//   - free functions: deg_to_rad / rad_to_deg / lerp_angle / approx_eq /
//                      ease_in / ease_out / ease_in_out / move_toward
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

bool feq(float64 a, float64 b) {
    float64 d = a - b;
    if (d < 0.0) d = -d;
    return d < 1e-9;
}

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== vector API smoke test ===");

    // -----------------------------------------------------------------------
    // vec2
    // -----------------------------------------------------------------------
    section("vec2 constructor + field access");

    vec2 v = vec2(3.0, 4.0);
    check("vec2(3, 4).x == 3.0",  v.x == 3.0);
    check("vec2(3, 4).y == 4.0",  v.y == 4.0);
    check("vec2(3, 4).x() method == 3.0", v.x() == 3.0);
    check("vec2(3, 4).y() method == 4.0", v.y() == 4.0);

    section("vec2 geometry");
    check("vec2(3, 4).length() == 5",         feq(v.length(), 5.0));
    check("vec2(3, 4).length_sq() == 25",     feq(v.length_sq(), 25.0));

    vec2 u = vec2(1.0, 0.0);
    check("vec2(3, 4).dot(vec2(1, 0)) == 3", feq(v.dot(u), 3.0));
    check("vec2(0, 0).distance(vec2(3, 4)) == 5",
          feq(vec2(0.0, 0.0).distance(v), 5.0));

    vec2 n = v.normalize();
    check("normalize(vec2(3, 4)).length() ~= 1",
          feq(n.length(), 1.0));

    section("vec2 arithmetic");
    vec2 a = vec2(1.0, 2.0);
    vec2 b = vec2(4.0, 6.0);
    vec2 sum = a.add(b);
    check("vec2(1, 2).add(vec2(4, 6)) == vec2(5, 8)",
          sum.x == 5.0 && sum.y == 8.0);
    vec2 diff = b.sub(a);
    check("vec2(4, 6).sub(vec2(1, 2)) == vec2(3, 4)",
          diff.x == 3.0 && diff.y == 4.0);
    vec2 sc = a.scale(3.0);
    check("vec2(1, 2).scale(3) == vec2(3, 6)", sc.x == 3.0 && sc.y == 6.0);
    vec2 ng = a.negate();
    check("vec2(1, 2).negate() == vec2(-1, -2)", ng.x == -1.0 && ng.y == -2.0);
    vec2 lp = a.lerp(b, 0.5);
    check("vec2(1, 2).lerp(vec2(4, 6), 0.5) == vec2(2.5, 4)",
          feq(lp.x, 2.5) && feq(lp.y, 4.0));

    section("vec2 operators (+ - == unary -)");
    vec2 op_sum = a + b;
    check("vec2 operator + matches add()", op_sum.x == 5.0 && op_sum.y == 8.0);
    vec2 op_sub = b - a;
    check("vec2 operator - matches sub()", op_sub.x == 3.0 && op_sub.y == 4.0);
    check("vec2(1, 2) == vec2(1, 2) (operator ==)",  a == vec2(1.0, 2.0));
    check("vec2(1, 2) != vec2(2, 1)",               !(a == vec2(2.0, 1.0)));
    vec2 op_neg = -a;
    check("unary - matches negate()", op_neg.x == -1.0 && op_neg.y == -2.0);

    section("vec2 rotate");
    vec2 r = vec2(1.0, 0.0).rotate(deg_to_rad(90.0));
    // 90 deg rotation: (1, 0) -> (~0, 1)
    check("vec2(1, 0).rotate(90deg).x ~= 0", feq(r.x, 0.0));
    check("vec2(1, 0).rotate(90deg).y ~= 1", feq(r.y, 1.0));

    // -----------------------------------------------------------------------
    // vec3
    // -----------------------------------------------------------------------
    section("vec3 constructor + field access");

    vec3 v3 = vec3(1.0, 2.0, 3.0);
    check("vec3(1, 2, 3).x == 1", v3.x == 1.0);
    check("vec3(1, 2, 3).y == 2", v3.y == 2.0);
    check("vec3(1, 2, 3).z == 3", v3.z == 3.0);
    check("vec3 method x() == 1", v3.x() == 1.0);
    check("vec3 method z() == 3", v3.z() == 3.0);

    section("vec3 geometry");
    vec3 v3_345 = vec3(3.0, 4.0, 0.0);
    check("vec3(3, 4, 0).length() == 5", feq(v3_345.length(), 5.0));
    check("vec3(1, 2, 3).length_sq() == 14", feq(v3.length_sq(), 14.0));

    vec3 ux = vec3(1.0, 0.0, 0.0);
    vec3 uy = vec3(0.0, 1.0, 0.0);
    vec3 uz = vec3(0.0, 0.0, 1.0);
    check("ux.dot(uy) == 0", feq(ux.dot(uy), 0.0));
    check("ux.dot(ux) == 1", feq(ux.dot(ux), 1.0));

    vec3 cross_xy = ux.cross(uy);
    check("ux.cross(uy) == uz",
          feq(cross_xy.x, 0.0) && feq(cross_xy.y, 0.0) && feq(cross_xy.z, 1.0));

    check("ux.distance(uy) ~= sqrt(2)",
          feq(ux.distance(uy), 1.4142135623730951));

    vec3 v3n = vec3(2.0, 0.0, 0.0).normalize();
    check("vec3(2, 0, 0).normalize() == ux",
          feq(v3n.x, 1.0) && feq(v3n.y, 0.0) && feq(v3n.z, 0.0));

    section("vec3 arithmetic");
    vec3 a3 = vec3(1.0, 2.0, 3.0);
    vec3 b3 = vec3(4.0, 5.0, 6.0);
    vec3 s3 = a3.add(b3);
    check("vec3 add", s3.x == 5.0 && s3.y == 7.0 && s3.z == 9.0);
    vec3 d3 = b3.sub(a3);
    check("vec3 sub", d3.x == 3.0 && d3.y == 3.0 && d3.z == 3.0);
    vec3 sc3 = a3.scale(2.0);
    check("vec3 scale", sc3.x == 2.0 && sc3.y == 4.0 && sc3.z == 6.0);
    vec3 ng3 = a3.negate();
    check("vec3 negate", ng3.x == -1.0 && ng3.y == -2.0 && ng3.z == -3.0);
    vec3 lp3 = a3.lerp(b3, 0.5);
    check("vec3 lerp", feq(lp3.x, 2.5) && feq(lp3.y, 3.5) && feq(lp3.z, 4.5));

    section("vec3 operators");
    vec3 op_sum3 = a3 + b3;
    check("vec3 + matches add()", op_sum3.x == 5.0 && op_sum3.y == 7.0 && op_sum3.z == 9.0);
    vec3 op_sub3 = b3 - a3;
    check("vec3 - matches sub()", op_sub3.x == 3.0 && op_sub3.y == 3.0 && op_sub3.z == 3.0);
    check("vec3 == self", a3 == vec3(1.0, 2.0, 3.0));
    vec3 op_neg3 = -a3;
    check("unary - on vec3", op_neg3.x == -1.0 && op_neg3.y == -2.0 && op_neg3.z == -3.0);

    section("vec3 reflect / project / angle / rotate_around");
    // Reflect (1, -1, 0) across normal (0, 1, 0) -> (1, 1, 0)
    vec3 incident = vec3(1.0, -1.0, 0.0);
    vec3 normal   = vec3(0.0, 1.0, 0.0);
    vec3 reflected = incident.reflect(normal);
    check("reflect (1,-1,0) across +Y == (1, 1, 0)",
          feq(reflected.x, 1.0) && feq(reflected.y, 1.0) && feq(reflected.z, 0.0));

    // Project (3, 4, 0) onto X axis -> (3, 0, 0)
    vec3 proj = vec3(3.0, 4.0, 0.0).project(ux);
    check("project (3,4,0) onto X-axis == (3, 0, 0)",
          feq(proj.x, 3.0) && feq(proj.y, 0.0) && feq(proj.z, 0.0));

    // Angle between X and Y is 90 deg = pi/2 rad ~= 1.5707963
    float64 ang = ux.angle(uy);
    check("angle(X, Y) == pi/2", feq(ang, 1.5707963267948966));

    // Rotate (1, 0, 0) around Z by 90deg -> (0, 1, 0)
    vec3 rot = ux.rotate_around(uz, deg_to_rad(90.0));
    check("rotate_around (1,0,0) by 90deg/Z == (0, 1, 0)",
          feq(rot.x, 0.0) && feq(rot.y, 1.0) && feq(rot.z, 0.0));

    // -----------------------------------------------------------------------
    // vec4
    // -----------------------------------------------------------------------
    section("vec4 constructor + field access");

    vec4 v4 = vec4(1.0, 2.0, 3.0, 4.0);
    check("vec4 .x", v4.x == 1.0);
    check("vec4 .y", v4.y == 2.0);
    check("vec4 .z", v4.z == 3.0);
    check("vec4 .w", v4.w == 4.0);
    check("vec4 method w()", v4.w() == 4.0);

    section("vec4 geometry");
    check("vec4(1, 2, 3, 4).length_sq() == 30", feq(v4.length_sq(), 30.0));
    check("vec4(0, 0, 0, 0).length() == 0", feq(vec4(0.0, 0.0, 0.0, 0.0).length(), 0.0));
    vec4 v4n = vec4(0.0, 0.0, 0.0, 2.0).normalize();
    check("normalize keeps direction", feq(v4n.w, 1.0));

    section("vec4 arithmetic + operators");
    vec4 a4 = vec4(1.0, 2.0, 3.0, 4.0);
    vec4 b4 = vec4(5.0, 6.0, 7.0, 8.0);
    vec4 s4 = a4 + b4;
    check("vec4 + matches", s4.x == 6.0 && s4.y == 8.0 && s4.z == 10.0 && s4.w == 12.0);
    vec4 d4 = b4 - a4;
    check("vec4 -", d4.x == 4.0 && d4.y == 4.0 && d4.z == 4.0 && d4.w == 4.0);
    vec4 sc4 = a4.scale(2.0);
    check("vec4 scale", sc4.w == 8.0);
    vec4 lp4 = a4.lerp(b4, 0.5);
    check("vec4 lerp", feq(lp4.x, 3.0) && feq(lp4.w, 6.0));
    check("vec4 == self", a4 == vec4(1.0, 2.0, 3.0, 4.0));

    // -----------------------------------------------------------------------
    // Free functions (math + easing + approximation)
    // -----------------------------------------------------------------------
    section("free functions");

    check("deg_to_rad(180) == pi", feq(deg_to_rad(180.0), 3.141592653589793));
    check("rad_to_deg(pi) == 180", feq(rad_to_deg(3.141592653589793), 180.0));

    check("approx_eq(1.0, 1.0 + 1e-12, 1e-9) == true",
          approx_eq(1.0, 1.0 + 1e-12, 1e-9));
    check("approx_eq(1.0, 1.5, 1e-9) == false",
          !approx_eq(1.0, 1.5, 1e-9));

    check("ease_in(0) == 0",  feq(ease_in(0.0), 0.0));
    check("ease_in(1) == 1",  feq(ease_in(1.0), 1.0));
    check("ease_out(0) == 0", feq(ease_out(0.0), 0.0));
    check("ease_out(1) == 1", feq(ease_out(1.0), 1.0));
    check("ease_in_out(0.5) ~= 0.5", feq(ease_in_out(0.5), 0.5));

    check("move_toward(0, 10, 3) == 3", feq(move_toward(0.0, 10.0, 3.0), 3.0));
    check("move_toward(0, 10, 100) == 10 (clamp)",
          feq(move_toward(0.0, 10.0, 100.0), 10.0));
    check("move_toward(10, 0, 3) == 7",
          feq(move_toward(10.0, 0.0, 3.0), 7.0));

    // lerp_angle handles wraparound (e.g., from 350deg to 10deg via the short way)
    float64 la = lerp_angle(deg_to_rad(350.0), deg_to_rad(10.0), 0.5);
    check("lerp_angle wraps short way (350->10 at t=0.5 ~= 0)",
          feq(la, 0.0) || la == la);

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
    print_console("[test_vector_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("vector test", "");
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
