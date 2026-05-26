// =============================================================================
// vectors.em  --  comprehensive test of the math addon vector API
//
// Types under test:
//   vec2  (2 x float64, 16 bytes)   .x .y
//   vec3  (3 x float64, 24 bytes)   .x .y .z
//   vec4  (4 x float64, 32 bytes)   .x .y .z .w
//
// Common methods (vec2 / vec3 / vec4):
//   .add()   .sub()   .scale()   .neg() / .negate()
//   .dot()   .length()   .length_sq()
//   .distance()   .normalize()   .lerp()
//
// vec2-only:
//   .rotate(rad)
//
// vec3-only:
//   .cross()   .reflect()   .project()
//   .angle()   .rotate_around()
//
// Operators:
//   +  -  * (scalar)  - (unary)  ==  !!  +=  -=
//
// Free functions (scalar helpers):
//   deg_to_rad    rad_to_deg
//   lerp_angle    move_toward
//   ease_in       ease_out     ease_in_out
//   approx_eq
// =============================================================================

import "math";

// -----------------------------------------------------------------------------
// test harness
// -----------------------------------------------------------------------------
int64 g_pass = 0;
int64 g_fail = 0;

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

// =============================================================================
// 1. Construction
// =============================================================================

void test_construction() {
    section("Construction");

    // 2-arg constructor
    vec2 v2 = vec2(1.0, 2.0);
    check("vec2(1,2).x == 1", v2.x == 1.0);
    check("vec2(1,2).y == 2", v2.y == 2.0);

    // 3-arg constructor
    vec3 v3 = vec3(1.0, 2.0, 3.0);
    check("vec3(1,2,3).x == 1", v3.x == 1.0);
    check("vec3(1,2,3).y == 2", v3.y == 2.0);
    check("vec3(1,2,3).z == 3", v3.z == 3.0);

    // 4-arg constructor
    vec4 v4 = vec4(1.0, 2.0, 3.0, 4.0);
    check("vec4(1,2,3,4).x == 1", v4.x == 1.0);
    check("vec4(1,2,3,4).y == 2", v4.y == 2.0);
    check("vec4(1,2,3,4).z == 3", v4.z == 3.0);
    check("vec4(1,2,3,4).w == 4", v4.w == 4.0);

    // Default constructor zeros all components
    vec3 zero;
    check("vec3 default.x == 0", zero.x == 0.0);
    check("vec3 default.y == 0", zero.y == 0.0);
    check("vec3 default.z == 0", zero.z == 0.0);

    vec2 zero2;
    check("vec2 default.x == 0", zero2.x == 0.0);
    check("vec2 default.y == 0", zero2.y == 0.0);

    vec4 zero4;
    check("vec4 default.x == 0", zero4.x == 0.0);
    check("vec4 default.y == 0", zero4.y == 0.0);
    check("vec4 default.z == 0", zero4.z == 0.0);
    check("vec4 default.w == 0", zero4.w == 0.0);
}

// =============================================================================
// 2. Component access (read + write)
// =============================================================================

void test_component_access() {
    section("Component access");

    // vec2 read
    vec2 v2 = vec2(10.0, 20.0);
    check("vec2 read x", v2.x == 10.0);
    check("vec2 read y", v2.y == 20.0);

    // vec2 write
    v2.x = 11.0;
    v2.y = 22.0;
    check("vec2 write x", v2.x == 11.0);
    check("vec2 write y", v2.y == 22.0);

    // vec3 read
    vec3 v3 = vec3(100.0, 200.0, 300.0);
    check("vec3 read x", v3.x == 100.0);
    check("vec3 read y", v3.y == 200.0);
    check("vec3 read z", v3.z == 300.0);

    // vec3 write
    v3.x = 101.0;
    v3.y = 202.0;
    v3.z = 303.0;
    check("vec3 write x", v3.x == 101.0);
    check("vec3 write y", v3.y == 202.0);
    check("vec3 write z", v3.z == 303.0);

    // vec4 read
    vec4 v4 = vec4(1.5, 2.5, 3.5, 4.5);
    check("vec4 read x", v4.x == 1.5);
    check("vec4 read y", v4.y == 2.5);
    check("vec4 read z", v4.z == 3.5);
    check("vec4 read w", v4.w == 4.5);

    // vec4 write
    v4.x = 10.5;
    v4.y = 20.5;
    v4.z = 30.5;
    v4.w = 40.5;
    check("vec4 write x", v4.x == 10.5);
    check("vec4 write y", v4.y == 20.5);
    check("vec4 write z", v4.z == 30.5);
    check("vec4 write w", v4.w == 40.5);
}

// =============================================================================
// 3. Operators
// =============================================================================

void test_operators() {
    section("Operators");

    vec3 a = vec3(1.0, 2.0, 3.0);
    vec3 b = vec3(4.0, 5.0, 6.0);

    // + addition (vec2 / vec3 / vec4)
    vec3 s = a + b;
    check("vec3 +", s.x == 5.0 && s.y == 7.0 && s.z == 9.0);

    vec2 a2 = vec2(1.0, 2.0);
    vec2 b2 = vec2(3.0, 4.0);
    vec2 s2 = a2 + b2;
    check("vec2 +", s2.x == 4.0 && s2.y == 6.0);

    vec4 a4 = vec4(1.0, 2.0, 3.0, 4.0);
    vec4 b4 = vec4(5.0, 6.0, 7.0, 8.0);
    vec4 s4 = a4 + b4;
    check("vec4 +", s4.x == 6.0 && s4.y == 8.0 && s4.z == 10.0 && s4.w == 12.0);

    // - subtraction (vec2 / vec3 / vec4)
    vec3 d = a - b;
    check("vec3 -", d.x == -3.0 && d.y == -3.0 && d.z == -3.0);

    vec2 d2 = a2 - b2;
    check("vec2 -", d2.x == -2.0 && d2.y == -2.0);

    vec4 d4 = a4 - b4;
    check("vec4 -", d4.x == -4.0 && d4.y == -4.0 && d4.z == -4.0 && d4.w == -4.0);

    // * scalar multiply (float64 RHS)
    vec3 k = a * 2.5;
    check("vec3 * scalar", k.x == 2.5 && k.y == 5.0 && k.z == 7.5);

    vec2 k2 = a2 * 3.0;
    check("vec2 * scalar", k2.x == 3.0 && k2.y == 6.0);

    vec4 k4 = a4 * 2.0;
    check("vec4 * scalar", k4.x == 2.0 && k4.y == 4.0 && k4.z == 6.0 && k4.w == 8.0);

    // unary negate
    vec3 n = -a;
    check("vec3 unary -", n.x == -1.0 && n.y == -2.0 && n.z == -3.0);

    vec2 n2 = -a2;
    check("vec2 unary -", n2.x == -1.0 && n2.y == -2.0);

    vec4 n4 = -a4;
    check("vec4 unary -", n4.x == -1.0 && n4.y == -2.0 && n4.z == -3.0 && n4.w == -4.0);

    // == component-wise equality
    check("vec3 == true",  (a == vec3(1.0, 2.0, 3.0)) == true);
    check("vec3 == false", (a == vec3(1.0, 0.0, 3.0)) == false);

    check("vec2 == true",  (a2 == vec2(1.0, 2.0)) == true);
    check("vec2 == false", (a2 == vec2(1.0, 0.0)) == false);

    check("vec4 == true",  (a4 == vec4(1.0, 2.0, 3.0, 4.0)) == true);
    check("vec4 == false", (a4 == vec4(1.0, 0.0, 3.0, 4.0)) == false);

    // !! truthy (false if all components 0)
    check("vec3 !! nonzero", !!a == true);
    check("vec3 !! zero", !!vec3(0.0, 0.0, 0.0) == false);

    check("vec2 !! nonzero", !!a2 == true);
    check("vec2 !! zero", !!vec2(0.0, 0.0) == false);

    check("vec4 !! nonzero", !!a4 == true);
    check("vec4 !! zero", !!vec4(0.0, 0.0, 0.0, 0.0) == false);

    // += compound addition
    vec3 ca = vec3(1.0, 2.0, 3.0);
    ca += vec3(4.0, 5.0, 6.0);
    check("vec3 +=", ca.x == 5.0 && ca.y == 7.0 && ca.z == 9.0);

    vec2 ca2 = vec2(1.0, 2.0);
    ca2 += vec2(3.0, 4.0);
    check("vec2 +=", ca2.x == 4.0 && ca2.y == 6.0);

    vec4 ca4 = vec4(1.0, 2.0, 3.0, 4.0);
    ca4 += vec4(5.0, 6.0, 7.0, 8.0);
    check("vec4 +=", ca4.x == 6.0 && ca4.y == 8.0 && ca4.z == 10.0 && ca4.w == 12.0);

    // -= compound subtraction
    vec3 cs = vec3(5.0, 7.0, 9.0);
    cs -= vec3(4.0, 5.0, 6.0);
    check("vec3 -=", cs.x == 1.0 && cs.y == 2.0 && cs.z == 3.0);

    vec2 cs2 = vec2(4.0, 6.0);
    cs2 -= vec2(3.0, 4.0);
    check("vec2 -=", cs2.x == 1.0 && cs2.y == 2.0);

    vec4 cs4 = vec4(6.0, 8.0, 10.0, 12.0);
    cs4 -= vec4(5.0, 6.0, 7.0, 8.0);
    check("vec4 -=", cs4.x == 1.0 && cs4.y == 2.0 && cs4.z == 3.0 && cs4.w == 4.0);
}

// =============================================================================
// 4. Common methods — vec2 / vec3 / vec4
// =============================================================================

void test_common_vec2() {
    section("vec2 common methods");

    vec2 a = vec2(1.0, 2.0);
    vec2 b = vec2(4.0, 5.0);

    vec2 r_add = a.add(b);
    check("vec2 add", r_add.x == 5.0 && r_add.y == 7.0);

    vec2 r_sub = a.sub(b);
    check("vec2 sub", r_sub.x == -3.0 && r_sub.y == -3.0);

    vec2 r_scale = a.scale(3.0);
    check("vec2 scale", r_scale.x == 3.0 && r_scale.y == 6.0);

    vec2 r_neg = a.neg();
    check("vec2 neg", r_neg.x == -1.0 && r_neg.y == -2.0);

    vec2 r_negate = a.negate();
    check("vec2 negate (alias)", r_negate.x == -1.0 && r_negate.y == -2.0);

    float64 d2 = a.dot(b);
    check("vec2 dot 4+10=14", d2 == 14.0);

    float64 l2 = a.length();
    // sqrt(1+4) = sqrt(5) ~ 2.23607
    check("vec2 length sqrt(5)", approx_eq(l2, 2.23606797749979, 0.000001));

    float64 lsq2 = a.length_sq();
    check("vec2 length_sq 1+4=5", lsq2 == 5.0);

    float64 dist2 = a.distance(b);
    // distance between (1,2) and (4,5) = sqrt(9+9) = sqrt(18) ~ 4.24264
    check("vec2 distance", approx_eq(dist2, 4.242640687119285, 0.000001));

    vec2 n2 = vec2(3.0, 0.0).normalize();
    check("vec2 normalize (3,0)->(1,0)", n2.x == 1.0 && n2.y == 0.0);

    // zero-length stays zero
    vec2 zero_n2 = vec2(0.0, 0.0).normalize();
    check("vec2 normalize zero stays zero", zero_n2.x == 0.0 && zero_n2.y == 0.0);

    vec2 l_2 = a.lerp(b, 0.5);
    check("vec2 lerp t=0.5", l_2.x == 2.5 && l_2.y == 3.5);

    vec2 l_2_0 = a.lerp(b, 0.0);
    check("vec2 lerp t=0", l_2_0.x == 1.0 && l_2_0.y == 2.0);

    vec2 l_2_1 = a.lerp(b, 1.0);
    check("vec2 lerp t=1", l_2_1.x == 4.0 && l_2_1.y == 5.0);
}

void test_common_vec3() {
    section("vec3 common methods");

    vec3 a = vec3(1.0, 2.0, 3.0);
    vec3 b = vec3(4.0, 5.0, 6.0);

    vec3 r_add = a.add(b);
    check("vec3 add", r_add.x == 5.0 && r_add.y == 7.0 && r_add.z == 9.0);

    vec3 r_sub = a.sub(b);
    check("vec3 sub", r_sub.x == -3.0 && r_sub.y == -3.0 && r_sub.z == -3.0);

    vec3 r_scale = a.scale(3.0);
    check("vec3 scale", r_scale.x == 3.0 && r_scale.y == 6.0 && r_scale.z == 9.0);

    vec3 r_neg = a.neg();
    check("vec3 neg", r_neg.x == -1.0 && r_neg.y == -2.0 && r_neg.z == -3.0);

    vec3 r_negate = a.negate();
    check("vec3 negate (alias)", r_negate.x == -1.0 && r_negate.y == -2.0 && r_negate.z == -3.0);

    float64 d = a.dot(b);
    check("vec3 dot 4+10+18=32", d == 32.0);

    float64 l = a.length();
    // sqrt(1+4+9) = sqrt(14) ~ 3.741657
    check("vec3 length sqrt(14)", approx_eq(l, 3.7416573867739413, 0.000001));

    float64 lsq = a.length_sq();
    check("vec3 length_sq 1+4+9=14", lsq == 14.0);

    float64 dist = a.distance(b);
    // distance between (1,2,3) and (4,5,6) = sqrt(9+9+9) = sqrt(27) ~ 5.19615
    check("vec3 distance sqrt(27)", approx_eq(dist, 5.196152422706632, 0.000001));

    vec3 n = vec3(5.0, 0.0, 0.0).normalize();
    check("vec3 normalize (5,0,0)->(1,0,0)", n.x == 1.0 && n.y == 0.0 && n.z == 0.0);

    // zero-length stays zero
    vec3 zero_n = vec3(0.0, 0.0, 0.0).normalize();
    check("vec3 normalize zero stays zero", zero_n.x == 0.0 && zero_n.y == 0.0 && zero_n.z == 0.0);

    vec3 l_ = a.lerp(b, 0.5);
    check("vec3 lerp t=0.5", l_.x == 2.5 && l_.y == 3.5 && l_.z == 4.5);

    vec3 l_0 = a.lerp(b, 0.0);
    check("vec3 lerp t=0", l_0.x == 1.0 && l_0.y == 2.0 && l_0.z == 3.0);

    vec3 l_1 = a.lerp(b, 1.0);
    check("vec3 lerp t=1", l_1.x == 4.0 && l_1.y == 5.0 && l_1.z == 6.0);
}

void test_common_vec4() {
    section("vec4 common methods");

    vec4 a = vec4(1.0, 2.0, 3.0, 4.0);
    vec4 b = vec4(5.0, 6.0, 7.0, 8.0);

    vec4 r_add = a.add(b);
    check("vec4 add", r_add.x == 6.0 && r_add.y == 8.0 && r_add.z == 10.0 && r_add.w == 12.0);

    vec4 r_sub = a.sub(b);
    check("vec4 sub", r_sub.x == -4.0 && r_sub.y == -4.0 && r_sub.z == -4.0 && r_sub.w == -4.0);

    vec4 r_scale = a.scale(2.0);
    check("vec4 scale", r_scale.x == 2.0 && r_scale.y == 4.0 && r_scale.z == 6.0 && r_scale.w == 8.0);

    vec4 r_neg = a.neg();
    check("vec4 neg", r_neg.x == -1.0 && r_neg.y == -2.0 && r_neg.z == -3.0 && r_neg.w == -4.0);

    vec4 r_negate = a.negate();
    check("vec4 negate (alias)", r_negate.x == -1.0 && r_negate.y == -2.0 && r_negate.z == -3.0 && r_negate.w == -4.0);

    float64 d = a.dot(b);
    check("vec4 dot 5+12+21+32=70", d == 70.0);

    float64 l = a.length();
    // sqrt(1+4+9+16) = sqrt(30) ~ 5.477225
    check("vec4 length sqrt(30)", approx_eq(l, 5.477225575051661, 0.000001));

    float64 lsq = a.length_sq();
    check("vec4 length_sq 1+4+9+16=30", lsq == 30.0);

    float64 dist = a.distance(b);
    // distance between (1,2,3,4) and (5,6,7,8) = sqrt(16+16+16+16) = sqrt(64) = 8
    check("vec4 distance", dist == 8.0);

    vec4 n = vec4(7.0, 0.0, 0.0, 0.0).normalize();
    check("vec4 normalize (7,0,0,0)->(1,0,0,0)", n.x == 1.0 && n.y == 0.0 && n.z == 0.0 && n.w == 0.0);

    // zero-length stays zero
    vec4 zero_n = vec4(0.0, 0.0, 0.0, 0.0).normalize();
    check("vec4 normalize zero stays zero", zero_n.x == 0.0 && zero_n.y == 0.0 && zero_n.z == 0.0 && zero_n.w == 0.0);

    vec4 l_ = a.lerp(b, 0.5);
    check("vec4 lerp t=0.5", l_.x == 3.0 && l_.y == 4.0 && l_.z == 5.0 && l_.w == 6.0);

    vec4 l_0 = a.lerp(b, 0.0);
    check("vec4 lerp t=0", l_0.x == 1.0 && l_0.y == 2.0 && l_0.z == 3.0 && l_0.w == 4.0);

    vec4 l_1 = a.lerp(b, 1.0);
    check("vec4 lerp t=1", l_1.x == 5.0 && l_1.y == 6.0 && l_1.z == 7.0 && l_1.w == 8.0);
}

// =============================================================================
// 5. vec2-only: rotate
// =============================================================================

void test_vec2_rotate() {
    section("vec2 rotate");

    // Rotate (1,0) CCW by 90 degrees (pi/2) -> (0,1)
    vec2 v = vec2(1.0, 0.0);
    vec2 r = v.rotate(1.5707963267948966);   // pi/2
    check("vec2 rotate 90deg CCW (1,0)->(0,1)",
        approx_eq(r.x, 0.0, 0.000001) && approx_eq(r.y, 1.0, 0.000001));

    // Rotate by 360 degrees (2*pi) should return to (1,0)
    vec2 r360 = v.rotate(6.283185307179586); // 2*pi
    check("vec2 rotate 360deg returns to start",
        approx_eq(r360.x, 1.0, 0.000001) && approx_eq(r360.y, 0.0, 0.000001));

    // Rotate by -90 degrees -> (0,-1)
    vec2 r_neg = v.rotate(-1.5707963267948966);
    check("vec2 rotate -90deg (1,0)->(0,-1)",
        approx_eq(r_neg.x, 0.0, 0.000001) && approx_eq(r_neg.y, -1.0, 0.000001));

    // Rotate (0,2) by 90deg -> (-2,0)
    vec2 v2 = vec2(0.0, 2.0);
    vec2 r2 = v2.rotate(1.5707963267948966);
    check("vec2 rotate 90deg (0,2)->(-2,0)",
        approx_eq(r2.x, -2.0, 0.000001) && approx_eq(r2.y, 0.0, 0.000001));

    // Rotate zero vector stays zero
    vec2 r_zero = vec2(0.0, 0.0).rotate(1.0);
    check("vec2 rotate zero stays zero", r_zero.x == 0.0 && r_zero.y == 0.0);
}

// =============================================================================
// 6. vec3-only: cross, reflect, project, angle, rotate_around
// =============================================================================

void test_vec3_cross() {
    section("vec3 cross");

    // (1,0,0) x (0,1,0) = (0,0,1)
    vec3 x_axis = vec3(1.0, 0.0, 0.0);
    vec3 y_axis = vec3(0.0, 1.0, 0.0);
    vec3 z_axis = x_axis.cross(y_axis);
    check("vec3 cross (1,0,0)x(0,1,0)=(0,0,1)",
        z_axis.x == 0.0 && z_axis.y == 0.0 && z_axis.z == 1.0);

    // Anti-commutative: y x x = -(x x y) = (0,0,-1)
    vec3 neg_z = y_axis.cross(x_axis);
    check("vec3 cross anti-commutative (0,1,0)x(1,0,0)=(0,0,-1)",
        neg_z.x == 0.0 && neg_z.y == 0.0 && neg_z.z == -1.0);

    // Cross of parallel vectors = zero
    vec3 parallel = vec3(2.0, 0.0, 0.0);
    vec3 zero_cross = x_axis.cross(parallel);
    check("vec3 cross parallel = 0",
        zero_cross.x == 0.0 && zero_cross.y == 0.0 && zero_cross.z == 0.0);

    // Self-cross = zero
    vec3 self_cross = x_axis.cross(x_axis);
    check("vec3 cross self = 0",
        self_cross.x == 0.0 && self_cross.y == 0.0 && self_cross.z == 0.0);
}

void test_vec3_reflect() {
    section("vec3 reflect");

    // Reflect (1,-1,0) across normal (0,1,0) -> (1,1,0)
    vec3 v = vec3(1.0, -1.0, 0.0);
    vec3 n = vec3(0.0, 1.0, 0.0);
    vec3 r = v.reflect(n);
    check("vec3 reflect (1,-1,0) across (0,1,0) -> (1,1,0)",
        approx_eq(r.x, 1.0, 0.000001) && approx_eq(r.y, 1.0, 0.000001) && approx_eq(r.z, 0.0, 0.000001));

    // Reflect (0,1,0) across (0,1,0) -> (0,-1,0)
    vec3 straight_down = vec3(0.0, 1.0, 0.0);
    vec3 reflected_down = straight_down.reflect(n);
    check("vec3 reflect straight down -> up",
        approx_eq(reflected_down.x, 0.0, 0.000001) && approx_eq(reflected_down.y, -1.0, 0.000001) && approx_eq(reflected_down.z, 0.0, 0.000001));
}

void test_vec3_project() {
    section("vec3 project");

    // Project (3,4,0) onto (1,0,0) -> (3,0,0)
    vec3 v = vec3(3.0, 4.0, 0.0);
    vec3 onto = vec3(1.0, 0.0, 0.0);
    vec3 p = v.project(onto);
    check("vec3 project onto x axis",
        approx_eq(p.x, 3.0, 0.000001) && p.y == 0.0 && p.z == 0.0);

    // Project (2,3,0) onto (1,1,0) -> (2.5,2.5,0)
    // dot(v,onto)=5, len_sq(onto)=2, (5/2)*(1,1,0) = (2.5,2.5,0)
    vec3 v2 = vec3(2.0, 3.0, 0.0);
    vec3 onto2 = vec3(1.0, 1.0, 0.0);
    vec3 p2 = v2.project(onto2);
    check("vec3 project onto diagonal",
        approx_eq(p2.x, 2.5, 0.000001) && approx_eq(p2.y, 2.5, 0.000001) && p2.z == 0.0);

    // Project onto zero vector should stay zero
    vec3 p_zero = v.project(vec3(0.0, 0.0, 0.0));
    check("vec3 project onto zero -> zero",
        p_zero.x == 0.0 && p_zero.y == 0.0 && p_zero.z == 0.0);
}

void test_vec3_angle() {
    section("vec3 angle");

    // Angle between (1,0,0) and (0,1,0) = pi/2
    vec3 x_axis = vec3(1.0, 0.0, 0.0);
    vec3 y_axis = vec3(0.0, 1.0, 0.0);
    float64 a90 = x_axis.angle(y_axis);
    check("vec3 angle between orthogonal = pi/2",
        approx_eq(a90, 1.5707963267948966, 0.000001));

    // Angle between (1,0,0) and (1,0,0) = 0
    float64 a0 = x_axis.angle(x_axis);
    check("vec3 angle with self = 0",
        approx_eq(a0, 0.0, 0.000001));

    // Angle between (1,0,0) and (-1,0,0) = pi
    float64 a180 = x_axis.angle(vec3(-1.0, 0.0, 0.0));
    check("vec3 angle between opposite = pi",
        approx_eq(a180, 3.141592653589793, 0.000001));

    // Angle between (1,1,0) and (1,0,0) = pi/4 (45 deg)
    vec3 diag = vec3(1.0, 1.0, 0.0);
    float64 a45 = diag.angle(x_axis);
    check("vec3 angle 45deg = pi/4",
        approx_eq(a45, 0.7853981633974483, 0.000001));

    // Angle between zero vector and anything = 0
    float64 a_zero = vec3(0.0, 0.0, 0.0).angle(x_axis);
    check("vec3 angle with zero = 0", a_zero == 0.0);
}

void test_vec3_rotate_around() {
    section("vec3 rotate_around");

    // Rotate (1,0,0) around Z axis by 90deg -> (0,1,0)
    vec3 v = vec3(1.0, 0.0, 0.0);
    vec3 axis_z = vec3(0.0, 0.0, 1.0);
    vec3 r = v.rotate_around(axis_z, 1.5707963267948966);
    check("vec3 rotate_around Z 90deg (1,0,0)->(0,1,0)",
        approx_eq(r.x, 0.0, 0.000001) && approx_eq(r.y, 1.0, 0.000001) && approx_eq(r.z, 0.0, 0.000001));

    // Rotate (0,1,0) around Z axis by 90deg -> (-1,0,0)
    vec3 v2 = vec3(0.0, 1.0, 0.0);
    vec3 r2 = v2.rotate_around(axis_z, 1.5707963267948966);
    check("vec3 rotate_around Z 90deg (0,1,0)->(-1,0,0)",
        approx_eq(r2.x, -1.0, 0.000001) && approx_eq(r2.y, 0.0, 0.000001) && approx_eq(r2.z, 0.0, 0.000001));

    // Rotate around non-axis-aligned axis (diagonal)
    vec3 diag_axis = vec3(1.0, 1.0, 0.0);  // axis is normalized internally
    vec3 r_diag = vec3(1.0, 0.0, 0.0).rotate_around(diag_axis, 3.141592653589793);
    // Should be reflected across the diagonal
    check("vec3 rotate_around diagonal pi rad",
        approx_eq(r_diag.x, 0.0, 0.0001) && approx_eq(r_diag.y, 1.0, 0.0001) && approx_eq(r_diag.z, 0.0, 0.0001));

    // Rotating zero vector stays zero
    vec3 r_zero = vec3(0.0, 0.0, 0.0).rotate_around(axis_z, 1.0);
    check("vec3 rotate_around zero stays zero", r_zero.x == 0.0 && r_zero.y == 0.0 && r_zero.z == 0.0);

    // Rotate by 0 rad stays unchanged
    vec3 r_no = vec3(1.0, 2.0, 3.0).rotate_around(axis_z, 0.0);
    check("vec3 rotate_around 0 rad unchanged",
        approx_eq(r_no.x, 1.0, 0.000001) && approx_eq(r_no.y, 2.0, 0.000001) && approx_eq(r_no.z, 3.0, 0.000001));
}

// =============================================================================
// 7. Scalar helpers (free functions)
// =============================================================================

void test_scalar_helpers() {
    section("Scalar helpers");

    // deg_to_rad
    float64 pi_val = deg_to_rad(180.0);
    check("deg_to_rad(180) ~ pi", approx_eq(pi_val, 3.141592653589793, 0.000001));

    float64 pi_half = deg_to_rad(90.0);
    check("deg_to_rad(90) ~ pi/2", approx_eq(pi_half, 1.5707963267948966, 0.000001));

    float64 zero_deg = deg_to_rad(0.0);
    check("deg_to_rad(0) == 0", zero_deg == 0.0);

    float64 full_deg = deg_to_rad(360.0);
    check("deg_to_rad(360) ~ 2*pi", approx_eq(full_deg, 6.283185307179586, 0.000001));

    float64 neg_deg = deg_to_rad(-180.0);
    check("deg_to_rad(-180) ~ -pi", approx_eq(neg_deg, -3.141592653589793, 0.000001));

    // rad_to_deg
    float64 d180 = rad_to_deg(3.141592653589793);
    check("rad_to_deg(pi) ~ 180", approx_eq(d180, 180.0, 0.000001));

    float64 d90 = rad_to_deg(1.5707963267948966);
    check("rad_to_deg(pi/2) ~ 90", approx_eq(d90, 90.0, 0.000001));

    float64 d0 = rad_to_deg(0.0);
    check("rad_to_deg(0) == 0", d0 == 0.0);

    float64 d360 = rad_to_deg(6.283185307179586);
    check("rad_to_deg(2*pi) ~ 360", approx_eq(d360, 360.0, 0.000001));

    // Roundtrip: deg -> rad -> deg
    float64 rt = rad_to_deg(deg_to_rad(45.0));
    check("deg->rad->deg roundtrip 45", approx_eq(rt, 45.0, 0.000001));

    // lerp_angle (shortest-path angular lerp, radians)
    float64 la_mid = lerp_angle(0.0, 3.141592653589793, 0.5);
    check("lerp_angle 0->pi t=0.5 ~ pi/2",
        approx_eq(la_mid, 1.5707963267948966, 0.000001));

    float64 la_start = lerp_angle(0.0, 3.141592653589793, 0.0);
    check("lerp_angle t=0", la_start == 0.0);

    float64 la_end = lerp_angle(0.0, 3.141592653589793, 1.0);
    check("lerp_angle t=1 ~ pi", approx_eq(la_end, 3.141592653589793, 0.000001));

    // Shortest path wraps: going from 350deg to 10deg in rad should go through 0, not around
    float64 la_wrap = lerp_angle(deg_to_rad(350.0), deg_to_rad(10.0), 0.5);
    check("lerp_angle 350->10 deg t=0.5 ~ 0 deg",
        approx_eq(la_wrap, 0.0, 0.000001));

    // lerp_angle with same start and end
    float64 la_same = lerp_angle(1.0, 1.0, 0.7);
    check("lerp_angle same start/end", approx_eq(la_same, 1.0, 0.000001));

    // move_toward: step toward target without overshooting
    float64 mt_reach = move_toward(0.0, 10.0, 5.0);
    check("move_toward 0->10 step 5 = 5", mt_reach == 5.0);

    float64 mt_exact = move_toward(0.0, 10.0, 10.0);
    check("move_toward exact step = target", mt_exact == 10.0);

    float64 mt_overshoot = move_toward(0.0, 10.0, 20.0);
    check("move_toward overshoot clamped to target", mt_overshoot == 10.0);

    float64 mt_back = move_toward(10.0, 0.0, 3.0);
    check("move_toward backward step 10->0 step 3 = 7", mt_back == 7.0);

    float64 mt_back_exact = move_toward(10.0, 0.0, 10.0);
    check("move_toward backward exact step = target", mt_back_exact == 0.0);

    float64 mt_zero_step = move_toward(5.0, 10.0, 0.0);
    check("move_toward zero step stays", mt_zero_step == 5.0);

    float64 mt_already_there = move_toward(5.0, 5.0, 1.0);
    check("move_toward already at target", mt_already_there == 5.0);

    // move_toward negative direction
    float64 mt_neg = move_toward(0.0, -10.0, 3.0);
    check("move_toward negative direction 0->-10 step 3 = -3", mt_neg == -3.0);

    // ease_in: t^2
    check("ease_in(0) == 0", ease_in(0.0) == 0.0);
    check("ease_in(1) == 1", ease_in(1.0) == 1.0);
    check("ease_in(0.5) == 0.25", ease_in(0.5) == 0.25);
    check("ease_in(0.3) == 0.09", ease_in(0.3) == 0.09);
    check("ease_in(1.2) == 1.44", ease_in(1.2) == 1.44);  // extrapolates

    // ease_out: 1 - (1-t)^2
    check("ease_out(0) == 0", ease_out(0.0) == 0.0);
    check("ease_out(1) == 1", ease_out(1.0) == 1.0);
    check("ease_out(0.5) == 0.75", ease_out(0.5) == 0.75);
    check("ease_out(0.3) == 0.51", approx_eq(ease_out(0.3), 0.51, 0.000001));  // 1 - 0.7^2 = 1 - 0.49 = 0.51

    // ease_in_out: quadratic in-out
    check("ease_in_out(0) == 0", ease_in_out(0.0) == 0.0);
    check("ease_in_out(1) == 1", ease_in_out(1.0) == 1.0);
    check("ease_in_out(0.5) == 0.5", ease_in_out(0.5) == 0.5);
    // At t=0.25: 2 * 0.25^2 = 2 * 0.0625 = 0.125
    check("ease_in_out(0.25) == 0.125", approx_eq(ease_in_out(0.25), 0.125, 0.000001));
    // At t=0.75: 1 - 2*(1-0.75)^2/2 ... actually: 1 - (1-0.75)^2*2 = 1 - 0.0625*2 = 1 - 0.125 = 0.875
    // Wait: quadratic in-out: t<0.5: 2t^2, t>=0.5: 1-2*(1-t)^2
    // t=0.75: 1 - 2*(0.25)^2 = 1 - 2*0.0625 = 1 - 0.125 = 0.875
    check("ease_in_out(0.75) == 0.875", approx_eq(ease_in_out(0.75), 0.875, 0.000001));

    // approx_eq: |a-b| <= eps
    check("approx_eq equal vals", approx_eq(1.0, 1.0, 0.001) == true);
    check("approx_eq within eps", approx_eq(1.0, 1.0005, 0.001) == true);
    check("approx_eq at boundary", approx_eq(1.0, 1.001, 0.001) == true);
    check("approx_eq over eps", approx_eq(1.0, 1.002, 0.001) == false);
    check("approx_eq negative within eps", approx_eq(-1.0, -1.0005, 0.001) == true);
    check("approx_eq zero eps exact", approx_eq(3.0, 3.0, 0.0) == true);
    check("approx_eq zero eps diff", approx_eq(3.0, 3.0001, 0.0) == false);
    check("approx_eq large diff", approx_eq(1.0, 2.0, 0.001) == false);
    check("approx_eq negative diff", approx_eq(-1.0, -1.0009, 0.001) == true);
    check("approx_eq negative over eps", approx_eq(-1.0, -1.002, 0.001) == false);
}

// =============================================================================
// Main entry
// =============================================================================

void main() {
    print_console("=== Vectors addon comprehensive test ===");

    test_construction();
    test_component_access();
    test_operators();
    test_common_vec2();
    test_common_vec3();
    test_common_vec4();
    test_vec2_rotate();
    test_vec3_cross();
    test_vec3_reflect();
    test_vec3_project();
    test_vec3_angle();
    test_vec3_rotate_around();
    test_scalar_helpers();

    // Summary
    print_console("");
    print_console("========================================");
    print_console("PASS: " + cast<string>(g_pass) + "   FAIL: " + cast<string>(g_fail));
    print_console("========================================");
}
