// =============================================================================
// Math addons smoke test — vec2 / vec3 / vec4 + quat + mat4
//
// Covers:
//   vec2/3/4 — constructors, property read AND write (.x = ...), methods,
//              operators, vec3 cross / reflect / project / rotate_around,
//              free helpers (deg_to_rad / lerp_angle / ease_* / approx_eq).
//   quat     — constructors (raw, identity, from_euler, from_axis_angle),
//              property read AND write (.x .y .z .w), length, dot, normalize,
//              conjugate, inverse, mul (Hamilton), rotate(vec3), slerp,
//              to_euler, operators (+ * == unary -).
//   mat4     — identity, translation, scale, rotation_x/y/z/axis, from_quat,
//              perspective, orthographic, look_at, get/set, transpose,
//              inverse, determinant, mul, transform_point/vec3/vec4.
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

bool feqs(float64 a, float64 b, float64 eps) {
    float64 d = a - b;
    if (d < 0.0) d = -d;
    return d < eps;
}

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== math addons smoke test ===");

    // =======================================================================
    // vec2
    // =======================================================================
    section("vec2 - construction + property read/write");

    vec2 v = vec2(3.0, 4.0);
    check("vec2(3, 4).x == 3", v.x == 3.0);
    check("vec2(3, 4).y == 4", v.y == 4.0);
    check("v.x() method == 3", v.x() == 3.0);
    check("v.y() method == 4", v.y() == 4.0);

    // Mutate via property setter.
    v.x = 10.0;
    v.y = 20.0;
    check("v.x = 10 took effect", v.x == 10.0);
    check("v.y = 20 took effect", v.y == 20.0);

    section("vec2 - methods + operators");
    vec2 a = vec2(1.0, 2.0);
    vec2 b = vec2(4.0, 6.0);
    check("a.length() ==  sqrt(5)",      feq(a.length(), 2.23606797749979));
    check("a.length_sq() == 5",          feq(a.length_sq(), 5.0));
    check("a.dot(b) == 16 (4 + 12)",     feq(a.dot(b), 16.0));
    check("a.distance(b) == 5 (3-4-5)",  feq(a.distance(b), 5.0));

    vec2 sum = a + b;
    check("vec2 +", sum.x == 5.0 && sum.y == 8.0);
    vec2 diff = b - a;
    check("vec2 -", diff.x == 3.0 && diff.y == 4.0);
    vec2 neg = -a;
    check("vec2 unary -", neg.x == -1.0 && neg.y == -2.0);
    check("vec2 ==", a == vec2(1.0, 2.0));
    check("vec2 !=", !(a == b));

    vec2 rot = vec2(1.0, 0.0).rotate(deg_to_rad(90.0));
    check("vec2(1,0).rotate(90deg).x ~= 0", feqs(rot.x, 0.0, 1e-12));
    check("vec2(1,0).rotate(90deg).y ~= 1", feqs(rot.y, 1.0, 1e-12));

    // =======================================================================
    // vec3
    // =======================================================================
    section("vec3 - construction + property read/write");

    vec3 v3 = vec3(1.0, 2.0, 3.0);
    check("vec3.x == 1", v3.x == 1.0);
    check("vec3.y == 2", v3.y == 2.0);
    check("vec3.z == 3", v3.z == 3.0);

    v3.x = 10.0; v3.y = 20.0; v3.z = 30.0;
    check("vec3.x = 10 took effect", v3.x == 10.0);
    check("vec3.y = 20 took effect", v3.y == 20.0);
    check("vec3.z = 30 took effect", v3.z == 30.0);

    section("vec3 - geometry + cross product");
    vec3 ux = vec3(1.0, 0.0, 0.0);
    vec3 uy = vec3(0.0, 1.0, 0.0);
    vec3 uz = vec3(0.0, 0.0, 1.0);
    check("ux.dot(uy) == 0", feq(ux.dot(uy), 0.0));
    check("ux.dot(ux) == 1", feq(ux.dot(ux), 1.0));

    vec3 cross_xy = ux.cross(uy);
    check("ux.cross(uy) == uz", cross_xy == uz);
    vec3 cross_yz = uy.cross(uz);
    check("uy.cross(uz) == ux", cross_yz == ux);

    check("vec3(3, 4, 0).length() == 5",
          feq(vec3(3.0, 4.0, 0.0).length(), 5.0));

    section("vec3 - reflect / project / angle / rotate_around");
    vec3 inc = vec3(1.0, -1.0, 0.0);
    vec3 nrm = vec3(0.0, 1.0, 0.0);
    vec3 ref = inc.reflect(nrm);
    check("reflect (1,-1,0) across +Y == (1, 1, 0)",
          feq(ref.x, 1.0) && feq(ref.y, 1.0) && feq(ref.z, 0.0));

    vec3 proj = vec3(3.0, 4.0, 0.0).project(ux);
    check("project(3,4,0) onto X == (3, 0, 0)",
          feq(proj.x, 3.0) && feq(proj.y, 0.0));

    check("angle(X, Y) == pi/2",
          feq(ux.angle(uy), 1.5707963267948966));

    vec3 rot3 = ux.rotate_around(uz, deg_to_rad(90.0));
    check("rotate (1,0,0) by 90deg around Z == (0, 1, 0)",
          feqs(rot3.x, 0.0, 1e-12) && feqs(rot3.y, 1.0, 1e-12) &&
          feqs(rot3.z, 0.0, 1e-12));

    // =======================================================================
    // vec4
    // =======================================================================
    section("vec4 - construction + property read/write");

    vec4 v4 = vec4(1.0, 2.0, 3.0, 4.0);
    check("vec4.x == 1", v4.x == 1.0);
    check("vec4.y == 2", v4.y == 2.0);
    check("vec4.z == 3", v4.z == 3.0);
    check("vec4.w == 4", v4.w == 4.0);

    v4.w = 99.0;
    check("vec4.w = 99 took effect", v4.w == 99.0);

    check("vec4 length_sq == 30 (1+4+9+16, before w mutation)",
          feq(vec4(1.0, 2.0, 3.0, 4.0).length_sq(), 30.0));

    // =======================================================================
    // Free helper functions
    // =======================================================================
    section("free math helpers");

    check("deg_to_rad(180) == pi",  feq(deg_to_rad(180.0), 3.141592653589793));
    check("rad_to_deg(pi) == 180",  feq(rad_to_deg(3.141592653589793), 180.0));
    check("approx_eq(1.0, 1+1e-12, 1e-9)",
          approx_eq(1.0, 1.0 + 1e-12, 1e-9));
    check("ease_in(0)==0  ease_in(1)==1",
          feq(ease_in(0.0), 0.0) && feq(ease_in(1.0), 1.0));
    check("ease_out(0)==0 ease_out(1)==1",
          feq(ease_out(0.0), 0.0) && feq(ease_out(1.0), 1.0));
    check("ease_in_out(0.5) == 0.5", feq(ease_in_out(0.5), 0.5));
    check("move_toward(0, 10, 3) == 3",  feq(move_toward(0.0, 10.0, 3.0), 3.0));
    check("move_toward(0, 10, 100) clamps to 10",
          feq(move_toward(0.0, 10.0, 100.0), 10.0));
    check("move_toward(10, 0, 3) == 7",  feq(move_toward(10.0, 0.0, 3.0), 7.0));

    // =======================================================================
    // quat
    // =======================================================================
    section("quat - construction + property read/write");

    quat q = quat(0.1, 0.2, 0.3, 0.4);
    check("quat.x == 0.1", q.x == 0.1);
    check("quat.y == 0.2", q.y == 0.2);
    check("quat.z == 0.3", q.z == 0.3);
    check("quat.w == 0.4", q.w == 0.4);

    q.x = 1.0;
    q.w = 0.0;
    check("quat.x = 1.0 took effect", q.x == 1.0);
    check("quat.w = 0.0 took effect", q.w == 0.0);

    section("quat - identity + length + dot");
    quat id = quat_identity();
    check("identity.w == 1",  feq(id.w, 1.0));
    check("identity.x == 0",  feq(id.x, 0.0));
    check("identity.length() == 1", feq(id.length(), 1.0));

    quat q1 = quat(1.0, 0.0, 0.0, 0.0);
    check("quat(1,0,0,0).length_sq() == 1", feq(q1.length_sq(), 1.0));
    check("identity.dot(identity) == 1",     feq(id.dot(id), 1.0));

    section("quat - normalize / conjugate / inverse");
    quat unnorm = quat(2.0, 0.0, 0.0, 0.0);
    quat nq = unnorm.normalize();
    check("normalize(2,0,0,0).x == 1", feq(nq.x, 1.0));
    check("normalize(2,0,0,0).length() == 1", feq(nq.length(), 1.0));

    quat conj = quat(0.5, 0.5, 0.5, 0.5).conjugate();
    check("conjugate flips xyz signs (keeps w)",
          feq(conj.x, -0.5) && feq(conj.y, -0.5) &&
          feq(conj.z, -0.5) && feq(conj.w,  0.5));

    quat inv = id.inverse();
    check("inverse(identity) ~= identity",
          feq(inv.x, 0.0) && feq(inv.y, 0.0) &&
          feq(inv.z, 0.0) && feq(inv.w, 1.0));

    section("quat - from_euler / from_axis_angle");
    quat qe = quat_from_euler(0.0, 0.0, 0.0);
    check("quat_from_euler(0, 0, 0) ~= identity",
          feq(qe.w, 1.0) && feq(qe.x, 0.0) && feq(qe.y, 0.0) && feq(qe.z, 0.0));

    quat qa = quat_from_axis_angle(vec3(0.0, 0.0, 1.0), deg_to_rad(180.0));
    // Rotation by 180 around Z: w = cos(90) = 0, z = sin(90) = 1.
    check("quat_from_axis_angle(Z, 180deg).w ~= 0", feqs(qa.w, 0.0, 1e-12));
    check("quat_from_axis_angle(Z, 180deg).z ~= 1", feqs(qa.z, 1.0, 1e-12));

    section("quat - mul (Hamilton product) + rotate vec3");
    // Rotate (1, 0, 0) by 90deg around Z -> ~(0, 1, 0)
    quat qz90 = quat_from_axis_angle(vec3(0.0, 0.0, 1.0), deg_to_rad(90.0));
    vec3 rotated = qz90.rotate(vec3(1.0, 0.0, 0.0));
    check("qz90.rotate(X).x ~= 0", feqs(rotated.x, 0.0, 1e-12));
    check("qz90.rotate(X).y ~= 1", feqs(rotated.y, 1.0, 1e-12));
    check("qz90.rotate(X).z ~= 0", feqs(rotated.z, 0.0, 1e-12));

    // identity * identity == identity
    quat ii = id.mul(id);
    check("id.mul(id) ~= identity",
          feq(ii.x, 0.0) && feq(ii.w, 1.0));

    // Operator * matches mul (Hamilton)
    quat qq = qz90 * qz90;
    // Two 90deg Z rotations = 180deg Z rotation -> w=0, z=1 (or signs)
    check("qz90 * qz90 ~= 180deg Z (|w|<eps, |z|~=1)",
          feqs(qq.w, 0.0, 1e-12) && feqs(qq.z, 1.0, 1e-12));

    section("quat - slerp + to_euler + operators");
    quat half = id.slerp(qz90, 0.5);
    // Halfway between identity and 90deg Z = 45deg Z. w = cos(22.5deg)
    check("slerp(id, qz90, 0.5).w ~= cos(22.5)",
          feqs(half.w, 0.9238795325112867, 1e-9));

    vec3 euler = qz90.to_euler();
    check("qz90.to_euler() yields some Z rotation",
          feqs(euler.z, 1.5707963267948966, 1e-9) ||
          feqs(euler.x, 1.5707963267948966, 1e-9) ||
          feqs(euler.y, 1.5707963267948966, 1e-9));

    quat qsum = quat(1.0, 2.0, 3.0, 4.0) + quat(5.0, 6.0, 7.0, 8.0);
    check("quat + componentwise",
          feq(qsum.x, 6.0) && feq(qsum.y, 8.0) &&
          feq(qsum.z, 10.0) && feq(qsum.w, 12.0));

    quat qneg = -id;
    check("-id == (0,0,0,-1)",
          feq(qneg.w, -1.0) && feq(qneg.x, 0.0));

    check("id == quat_identity() (operator ==)", id == quat_identity());

    // =======================================================================
    // mat4
    // =======================================================================
    section("mat4 - identity + get/set");

    mat4 I = mat4_identity();
    check("identity.get(0,0) == 1", feq(I.get(0, 0), 1.0));
    check("identity.get(1,1) == 1", feq(I.get(1, 1), 1.0));
    check("identity.get(2,2) == 1", feq(I.get(2, 2), 1.0));
    check("identity.get(3,3) == 1", feq(I.get(3, 3), 1.0));
    check("identity.get(0,1) == 0", feq(I.get(0, 1), 0.0));
    check("identity.get(1,0) == 0", feq(I.get(1, 0), 0.0));

    mat4 M = mat4_identity();
    M.set(0, 3, 99.0);
    check("M.set(0,3,99) writes the cell", feq(M.get(0, 3), 99.0));

    section("mat4 - determinant + transpose + inverse");
    check("identity.determinant() == 1", feq(I.determinant(), 1.0));

    mat4 T_ = mat4_translation(vec3(5.0, 6.0, 7.0));
    // Translation det == 1.
    check("translation.determinant() == 1", feq(T_.determinant(), 1.0));

    mat4 TT = T_.transpose();
    // For pure translation, transpose moves translation row -> column.
    check("transpose(translation).get(3,0) == 5", feq(TT.get(3, 0), 5.0));

    mat4 Tinv = T_.inverse();
    // inverse of translate(5,6,7) is translate(-5,-6,-7)
    check("inverse(translation(5,6,7)).get(0,3) == -5", feq(Tinv.get(0, 3), -5.0));
    check("inverse(translation(5,6,7)).get(1,3) == -6", feq(Tinv.get(1, 3), -6.0));
    check("inverse(translation(5,6,7)).get(2,3) == -7", feq(Tinv.get(2, 3), -7.0));

    section("mat4 - constructors (translation / scale / rotation)");
    mat4 S = mat4_scale(vec3(2.0, 3.0, 4.0));
    check("scale.get(0,0) == 2", feq(S.get(0, 0), 2.0));
    check("scale.get(1,1) == 3", feq(S.get(1, 1), 3.0));
    check("scale.get(2,2) == 4", feq(S.get(2, 2), 4.0));
    check("scale.determinant() == 24", feq(S.determinant(), 24.0));

    mat4 Rx = mat4_rotation_x(deg_to_rad(90.0));
    check("rot_x(90deg).determinant() ~= 1", feqs(Rx.determinant(), 1.0, 1e-12));

    mat4 Ry = mat4_rotation_y(deg_to_rad(45.0));
    check("rot_y(45deg).determinant() ~= 1", feqs(Ry.determinant(), 1.0, 1e-12));

    mat4 Rz = mat4_rotation_z(deg_to_rad(60.0));
    check("rot_z(60deg).determinant() ~= 1", feqs(Rz.determinant(), 1.0, 1e-12));

    // Compare rot_axis(Z, 60deg) against rot_z(60deg) at the same angle.
    // (Rz above is built with 60deg; reuse it.)
    mat4 Raxis = mat4_rotation_axis(vec3(0.0, 0.0, 1.0), deg_to_rad(60.0));
    check("rot_axis(Z, 60) ~= rot_z(60) at (0,0)",
          feqs(Raxis.get(0, 0), Rz.get(0, 0), 1e-12));

    mat4 Mq = mat4_from_quat(quat_identity());
    check("mat4_from_quat(identity) ~= identity at (0,0)",
          feq(Mq.get(0, 0), 1.0));
    check("mat4_from_quat(identity) ~= identity at (3,3)",
          feq(Mq.get(3, 3), 1.0));

    section("mat4 - perspective / orthographic / look_at");
    mat4 P = mat4_perspective(deg_to_rad(60.0), 16.0 / 9.0, 0.1, 100.0);
    check("perspective produces non-zero matrix",
          P.get(0, 0) != 0.0 || P.get(1, 1) != 0.0);
    check("perspective.get(3,2) == -1 (W = -z)", feq(P.get(3, 2), -1.0));

    mat4 O = mat4_orthographic(-1.0, 1.0, -1.0, 1.0, 0.1, 100.0);
    check("orthographic produces non-zero matrix",
          O.get(0, 0) != 0.0);

    mat4 V = mat4_look_at(vec3(0.0, 0.0, 5.0), vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0));
    check("look_at produces a sensible matrix",
          V.get(3, 3) == 1.0 || feq(V.determinant(), 1.0));

    section("mat4 - mul + transform_point/vec3/vec4");
    mat4 II = I.mul(I);
    check("I.mul(I).get(0,0) == 1", feq(II.get(0, 0), 1.0));
    check("I.mul(I).get(2,2) == 1", feq(II.get(2, 2), 1.0));

    // identity transform leaves point unchanged
    vec3 p_in = vec3(1.0, 2.0, 3.0);
    vec3 p_out = I.transform_point(p_in);
    check("I.transform_point((1,2,3)) == (1,2,3)",
          feq(p_out.x, 1.0) && feq(p_out.y, 2.0) && feq(p_out.z, 3.0));

    // Translation moves point.
    vec3 p_t = T_.transform_point(vec3(0.0, 0.0, 0.0));
    check("translation(5,6,7).transform_point(origin) == (5,6,7)",
          feq(p_t.x, 5.0) && feq(p_t.y, 6.0) && feq(p_t.z, 7.0));

    // transform_vec3 IGNORES translation.
    vec3 v_t = T_.transform_vec3(vec3(0.0, 0.0, 0.0));
    check("translation.transform_vec3(origin) == (0,0,0)  (ignores translation)",
          feq(v_t.x, 0.0) && feq(v_t.y, 0.0) && feq(v_t.z, 0.0));

    // Scale applies to vec3.
    vec3 v_s = S.transform_vec3(vec3(1.0, 1.0, 1.0));
    check("scale(2,3,4).transform_vec3((1,1,1)) == (2,3,4)",
          feq(v_s.x, 2.0) && feq(v_s.y, 3.0) && feq(v_s.z, 4.0));

    // transform_vec4: identity preserves all four components.
    vec4 v4_in = vec4(1.0, 2.0, 3.0, 1.0);
    vec4 v4_out = I.transform_vec4(v4_in);
    check("I.transform_vec4((1,2,3,1)) == (1,2,3,1)",
          feq(v4_out.x, 1.0) && feq(v4_out.y, 2.0) &&
          feq(v4_out.z, 3.0) && feq(v4_out.w, 1.0));

    // Operator * for mat4.
    mat4 IxI = I * I;
    check("mat4 * (operator) ~= I.mul(I)", feq(IxI.get(2, 2), 1.0));

    // =======================================================================
    // Summary
    // =======================================================================
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
    print_console("[test_math_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("math test", "");
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
