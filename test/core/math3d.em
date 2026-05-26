// ============================================================================
// math3d.em -- comprehensive exercise of every quat and mat4 type, method,
//               standalone function, operator, and common pattern
// ============================================================================
//
// Checklist -- every type, every method, every function covered:
//
// Legend: T = type, F = free function, M = method, O = operator, A = accessor
//
// -- Types ---------------------------------------------------------------
//   T  quat                        T  mat4
//
// -- quat fields (direct access) -----------------------------------------
//   A  q.x    q.y    q.z    q.w
//
// -- quat free functions (standalone) ------------------------------------
//   F  quat_identity()             F  quat_from_euler(yaw, pitch, roll)
//   F  quat_from_axis_angle(vec3, angle)
//
// -- quat methods --------------------------------------------------------
//   M  q.normalize()               M  q.conjugate()
//   M  q.inverse()                 M  a.mul(b)              [Hamilton]
//   M  a.add(b)                    M  q.negate()
//   M  q.neg()                     M  a.dot(b)
//   M  q.length()                  M  q.length_sq()
//   M  q.rotate(vec3)              M  q.to_euler()
//   M  a.slerp(b, t)
//
// -- quat operators ------------------------------------------------------
//   O  a * b   a + b   -q   a == b   a += b   a -= b
//
// -- mat4 fields (direct access) -----------------------------------------
//   A  m.m00 .. m.m33  (16 fields)
//
// -- mat4 free functions (standalone) ------------------------------------
//   F  mat4_identity()             F  mat4_translation(vec3)
//   F  mat4_scale(vec3)            F  mat4_rotation_x(rad)
//   F  mat4_rotation_y(rad)        F  mat4_rotation_z(rad)
//   F  mat4_rotation_axis(vec3, rad)
//   F  mat4_from_quat(quat)        F  mat4_perspective(fov, aspect, n, f)
//   F  mat4_orthographic(l,r,b,t,n,f)
//   F  mat4_look_at(eye, target, up)
//   F  mat4_get(m, row, col)       F  mat4_set(m, row, col, v)
//
// -- mat4 methods --------------------------------------------------------
//   M  m.get(row, col)             M  m.set(row, col, v)
//   M  m.transpose()               M  m.inverse()
//   M  m.determinant()             M  a.mul(b)
//   M  m.scale(s)                  M  m.neg()
//   M  m.transform_point(vec3)     M  m.transform_vec3(vec3)
//   M  m.transform_vec4(vec4)
//
// -- mat4 operators ------------------------------------------------------
//   O  a * b   a + b   a - b   -m   a == b
//   O  a += b  a -= b  a *= b
//
// -- Common patterns -----------------------------------------------------
//   Pattern: TRS world matrix
//   Pattern: View-projection matrix
//   Pattern: Slerp between orientations
// ============================================================================

import "math";

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

void print_console(string input) {
    print(input);
}

// ============================================================================
// Helper: approximate equality for float64
// ============================================================================

bool approx(float64 a, float64 b, float64 eps) {
    float64 d = a - b;
    if (d < 0) { d = -d; }
    return d <= eps;
}

// ============================================================================
// 1. quat default construction and field access
// ============================================================================

void test_quat_construct_default() {
    section("quat - default construction and field access");

    // Default construct: all zeros
    quat q;
    check("quat default x == 0", q.x == 0.0);
    check("quat default y == 0", q.y == 0.0);
    check("quat default z == 0", q.z == 0.0);
    check("quat default w == 0", q.w == 0.0);

    // Write fields directly
    q.x = 1.0;
    q.y = 2.0;
    q.z = 3.0;
    q.w = 4.0;
    check("quat field write x == 1", q.x == 1.0);
    check("quat field write y == 2", q.y == 2.0);
    check("quat field write z == 3", q.z == 3.0);
    check("quat field write w == 4", q.w == 4.0);
}

// ============================================================================
// 2. quat explicit construction with components
// ============================================================================

void test_quat_construct_explicit() {
    section("quat - explicit component construction");

    quat q4 = quat(1.0, 0.0, 0.0, 0.0);
    check("quat(1,0,0,0) x == 1", q4.x == 1.0);
    check("quat(1,0,0,0) y == 0", q4.y == 0.0);
    check("quat(1,0,0,0) z == 0", q4.z == 0.0);
    check("quat(1,0,0,0) w == 0", q4.w == 0.0);
}

// ============================================================================
// 3. quat standalone free functions
// ============================================================================

void test_quat_free_functions() {
    section("quat - standalone free functions");

    // quat_identity
    quat id = quat_identity();
    check("quat_identity x == 0", id.x == 0.0);
    check("quat_identity y == 0", id.y == 0.0);
    check("quat_identity z == 0", id.z == 0.0);
    check("quat_identity w == 1", id.w == 1.0);

    // quat_from_euler (Tait-Bryan ZYX, radians)
    float64 yaw = 0.0;
    float64 pitch = 0.0;
    float64 roll = deg_to_rad(90.0);
    quat e = quat_from_euler(yaw, pitch, roll);
    // At minimum, verify w is non-zero (a valid rotation was computed)
    check("quat_from_euler(0,0,90deg) w != 0", e.w != 0.0);

    // quat_from_axis_angle (90 degrees around Z)
    quat a = quat_from_axis_angle(vec3(0.0, 0.0, 1.0), deg_to_rad(90.0));
    check("quat_from_axis_angle(z,90) w ~= 0.707", approx(a.w, 0.70710678, 1e-6));
    check("quat_from_axis_angle(z,90) z ~= 0.707", approx(a.z, 0.70710678, 1e-6));
}

// ============================================================================
// 4. quat methods
// ============================================================================

void test_quat_methods() {
    section("quat - methods");

    quat id = quat_identity();
    // A non-trivial quat: 90 degrees around Z
    quat qz = quat_from_axis_angle(vec3(0.0, 0.0, 1.0), deg_to_rad(90.0));
    // Another quat: 45 degrees around Z
    quat qz45 = quat_from_axis_angle(vec3(0.0, 0.0, 1.0), deg_to_rad(45.0));

    // normalize
    quat n = qz.normalize();
    check("quat normalize length ~= 1", approx(n.length(), 1.0, 1e-6));

    // conjugate: xyz negated, w preserved
    quat c = qz.conjugate();
    check("quat conjugate x == -qz.x", approx(c.x, -qz.x, 1e-6));
    check("quat conjugate y == -qz.y", approx(c.y, -qz.y, 1e-6));
    check("quat conjugate z == -qz.z", approx(c.z, -qz.z, 1e-6));
    check("quat conjugate w == qz.w", approx(c.w, qz.w, 1e-6));

    // inverse (conjugate when unit-length)
    quat inv = qz.inverse();
    check("quat inverse length ~= 1", approx(inv.length(), 1.0, 1e-6));
    check("quat inverse ~= conjugate (unit)", approx(inv.z, -qz.z, 1e-6));

    // mul (Hamilton product)
    quat mul_result = qz.mul(qz45);
    quat op_result = qz * qz45;
    check("quat mul == operator*", approx(mul_result.x, op_result.x, 1e-6));
    check("quat mul == operator* (y)", approx(mul_result.y, op_result.y, 1e-6));
    check("quat mul == operator* (z)", approx(mul_result.z, op_result.z, 1e-6));
    check("quat mul == operator* (w)", approx(mul_result.w, op_result.w, 1e-6));

    // add (component-wise)
    quat add_result = qz.add(id);
    quat add_op = qz + id;
    check("quat add == operator+", approx(add_result.x, add_op.x, 1e-6));

    // negate
    quat ng = qz.negate();
    check("quat negate x == -qz.x", approx(ng.x, -qz.x, 1e-6));
    check("quat negate w == -qz.w", approx(ng.w, -qz.w, 1e-6));

    // neg (alias for negate)
    quat ng2 = qz.neg();
    check("quat neg x == negate x", approx(ng2.x, ng.x, 1e-6));
    check("quat neg y == negate y", approx(ng2.y, ng.y, 1e-6));

    // dot
    float64 d = id.dot(id);
    check("quat identity dot identity == 1", approx(d, 1.0, 1e-6));

    float64 d_ortho = id.dot(qz);
    // id and qz are different, dot should be non-trivial
    check("quat dot returns finite", is_finite(d_ortho));

    // length
    float64 L = id.length();
    check("quat identity length == 1", approx(L, 1.0, 1e-6));

    // length_sq
    float64 Lsq = id.length_sq();
    check("quat identity length_sq == 1", approx(Lsq, 1.0, 1e-6));

    // rotate (assumes unit quat)
    vec3 vz = vec3(0.0, 0.0, 1.0);
    vec3 rotated = qz.rotate(vz);
    // Rotating Z by 90deg around Z should give Z (parallel to axis)
    check("quat rotate(z, z-axis) z ~= 1", approx(rotated.z, 1.0, 1e-6));

    // Rotate X by 90deg around Z => should produce Y
    vec3 vx = vec3(1.0, 0.0, 0.0);
    vec3 rx = qz.rotate(vx);
    check("quat rotate(x, z=90deg) x ~= 0", approx(rx.x, 0.0, 1e-6));
    check("quat rotate(x, z=90deg) y ~= 1", approx(rx.y, 1.0, 1e-6));

    // to_euler
    vec3 euler = id.to_euler();
    check("quat identity to_euler yaw == 0", approx(euler.x, 0.0, 1e-6));
    check("quat identity to_euler pitch == 0", approx(euler.y, 0.0, 1e-6));
    check("quat identity to_euler roll == 0", approx(euler.z, 0.0, 1e-6));

    vec3 euler2 = qz.to_euler();
    check("quat qz to_euler returns finite", is_finite(euler2.x));

    // slerp
    quat midway = id.slerp(qz, 0.5);
    check("quat slerp(0.5) w ~= cos(45deg/2)", approx(midway.w, 0.92387953, 1e-6));

    // slerp at t=0 should equal a
    quat at_zero = id.slerp(qz, 0.0);
    check("quat slerp t=0 == a", approx(at_zero.x, id.x, 1e-6));

    // slerp at t=1 should equal b
    quat at_one = id.slerp(qz, 1.0);
    check("quat slerp t=1 == b", approx(at_one.x, qz.x, 1e-6));
}

// ============================================================================
// 5. quat operators
// ============================================================================

void test_quat_operators() {
    section("quat - operators");

    quat id = quat_identity();
    quat qz = quat_from_axis_angle(vec3(0.0, 0.0, 1.0), deg_to_rad(90.0));

    // a * b (Hamilton product)
    quat prod = qz * id;
    check("quat qz * id == qz", approx(prod.x, qz.x, 1e-6));
    check("quat qz * id == qz (w)", approx(prod.w, qz.w, 1e-6));

    // a + b (component-wise)
    quat sum = qz + id;
    check("quat qz + id w ~= 2", approx(sum.w, 2.0, 1e-6));

    // -q (unary negate)
    quat neg = -qz;
    check("quat -qz x == -qz.x", approx(neg.x, -qz.x, 1e-6));

    // a == b (exact-component equality)
    check("quat qz == qz", qz == qz);
    check("quat qz != id", !(qz == id));

    // a += b
    quat accum = id;
    accum += id;
    check("quat id += id w == 2", approx(accum.w, 2.0, 1e-6));

    // a -= b
    accum -= id;
    check("quat (id+id) -= id w == 1", approx(accum.w, 1.0, 1e-6));
}

// ============================================================================
// 6. mat4 default construction and field access (m00 .. m33)
// ============================================================================

void test_mat4_construct_default_and_fields() {
    section("mat4 - default construction and field access");

    // Default construct: all zeros
    mat4 zero;
    check("mat4 default m00 == 0", zero.m00 == 0.0);
    check("mat4 default m01 == 0", zero.m01 == 0.0);
    check("mat4 default m02 == 0", zero.m02 == 0.0);
    check("mat4 default m03 == 0", zero.m03 == 0.0);
    check("mat4 default m10 == 0", zero.m10 == 0.0);
    check("mat4 default m11 == 0", zero.m11 == 0.0);
    check("mat4 default m12 == 0", zero.m12 == 0.0);
    check("mat4 default m13 == 0", zero.m13 == 0.0);
    check("mat4 default m20 == 0", zero.m20 == 0.0);
    check("mat4 default m21 == 0", zero.m21 == 0.0);
    check("mat4 default m22 == 0", zero.m22 == 0.0);
    check("mat4 default m23 == 0", zero.m23 == 0.0);
    check("mat4 default m30 == 0", zero.m30 == 0.0);
    check("mat4 default m31 == 0", zero.m31 == 0.0);
    check("mat4 default m32 == 0", zero.m32 == 0.0);
    check("mat4 default m33 == 0", zero.m33 == 0.0);

    // Write fields directly
    zero.m00 = 1.0; zero.m01 = 2.0; zero.m02 = 3.0; zero.m03 = 4.0;
    zero.m10 = 5.0; zero.m11 = 6.0; zero.m12 = 7.0; zero.m13 = 8.0;
    zero.m20 = 9.0; zero.m21 = 10.0; zero.m22 = 11.0; zero.m23 = 12.0;
    zero.m30 = 13.0; zero.m31 = 14.0; zero.m32 = 15.0; zero.m33 = 16.0;
    check("mat4 field write m00 == 1", zero.m00 == 1.0);
    check("mat4 field write m11 == 6", zero.m11 == 6.0);
    check("mat4 field write m22 == 11", zero.m22 == 11.0);
    check("mat4 field write m33 == 16", zero.m33 == 16.0);
}

// ============================================================================
// 7. mat4 standalone free functions (construction)
// ============================================================================

void test_mat4_free_functions() {
    section("mat4 - standalone free functions");

    // mat4_identity
    mat4 i = mat4_identity();
    check("mat4_identity m00 == 1", i.m00 == 1.0);
    check("mat4_identity m11 == 1", i.m11 == 1.0);
    check("mat4_identity m22 == 1", i.m22 == 1.0);
    check("mat4_identity m33 == 1", i.m33 == 1.0);
    check("mat4_identity m01 == 0 (off-diag)", i.m01 == 0.0);

    // mat4_translation
    mat4 t = mat4_translation(vec3(10.0, 20.0, 30.0));
    check("mat4_translation m03 == 10", approx(t.m03, 10.0, 1e-6));
    check("mat4_translation m13 == 20", approx(t.m13, 20.0, 1e-6));
    check("mat4_translation m23 == 30", approx(t.m23, 30.0, 1e-6));
    check("mat4_translation m00 == 1 (diag preserved)", t.m00 == 1.0);

    // mat4_scale
    mat4 s = mat4_scale(vec3(2.0, 3.0, 4.0));
    check("mat4_scale m00 == 2", approx(s.m00, 2.0, 1e-6));
    check("mat4_scale m11 == 3", approx(s.m11, 3.0, 1e-6));
    check("mat4_scale m22 == 4", approx(s.m22, 4.0, 1e-6));
    check("mat4_scale m33 == 1 (diag preserved)", s.m33 == 1.0);

    // mat4_rotation_x
    float64 angle = deg_to_rad(30.0);
    mat4 rx = mat4_rotation_x(angle);
    check("mat4_rotation_x m00 == 1", approx(rx.m00, 1.0, 1e-6));

    // mat4_rotation_y
    mat4 ry = mat4_rotation_y(angle);
    check("mat4_rotation_y m11 == 1", approx(ry.m11, 1.0, 1e-6));

    // mat4_rotation_z
    mat4 rz = mat4_rotation_z(angle);
    check("mat4_rotation_z m22 == 1", approx(rz.m22, 1.0, 1e-6));

    // mat4_rotation_axis (Rodrigues)
    mat4 ra = mat4_rotation_axis(vec3(0.0, 1.0, 0.0), deg_to_rad(90.0));
    check("mat4_rotation_axis returns finite", is_finite(ra.m00));

    // mat4_from_quat
    quat qid = quat_identity();
    mat4 fq = mat4_from_quat(qid);
    check("mat4_from_quat(identity) m00 == 1", approx(fq.m00, 1.0, 1e-6));
    check("mat4_from_quat(identity) m11 == 1", approx(fq.m11, 1.0, 1e-6));
    check("mat4_from_quat(identity) m22 == 1", approx(fq.m22, 1.0, 1e-6));
    check("mat4_from_quat(identity) m33 == 1", approx(fq.m33, 1.0, 1e-6));

    // mat4_perspective (RH, GL-style depth)
    mat4 p = mat4_perspective(deg_to_rad(60.0), 16.0 / 9.0, 0.1, 1000.0);
    check("mat4_perspective returns finite", is_finite(p.m00));
    check("mat4_perspective m11 < 0 (RH)", p.m11 < 0.0);

    // mat4_orthographic
    mat4 o = mat4_orthographic(-10.0, 10.0, -5.0, 5.0, 0.1, 100.0);
    check("mat4_orthographic returns finite", is_finite(o.m00));

    // mat4_look_at (RH view matrix)
    mat4 v = mat4_look_at(vec3(0.0, 0.0, 10.0), vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0));
    check("mat4_look_at returns finite", is_finite(v.m00));
}

// ============================================================================
// 8. mat4 methods
// ============================================================================

void test_mat4_methods() {
    section("mat4 - methods");

    mat4 i = mat4_identity();
    mat4 t = mat4_translation(vec3(5.0, 10.0, 15.0));
    mat4 s = mat4_scale(vec3(2.0, 3.0, 4.0));

    // get / set methods
    float64 cell = i.get(0, 0);
    check("mat4 identity get(0,0) == 1", cell == 1.0);

    float64 cell_off = i.get(0, 1);
    check("mat4 identity get(0,1) == 0", cell_off == 0.0);

    // set then verify
    mat4 mset;
    mset.set(0, 0, 42.0);
    mset.set(1, 2, 99.0);
    mset.set(3, 3, 77.0);
    check("mat4 set(0,0) m00 == 42", mset.m00 == 42.0);
    check("mat4 set(1,2) m12 == 99", mset.m12 == 99.0);
    check("mat4 set(3,3) m33 == 77", mset.m33 == 77.0);

    // verify via get
    check("mat4 get(1,2) == 99", mset.get(1, 2) == 99.0);

    // mat4_get free-function alias
    float64 g_val = mat4_get(i, 0, 0);
    check("mat4_get(i, 0, 0) == 1", g_val == 1.0);

    // mat4_set free-function alias
    mat4 mset2;
    mat4_set(mset2, 0, 0, 55.0);
    check("mat4_set m00 == 55", mset2.m00 == 55.0);

    // transpose of identity is identity
    mat4 trans = i.transpose();
    check("mat4 identity transpose m00 == 1", trans.m00 == 1.0);
    check("mat4 identity transpose m33 == 1", trans.m33 == 1.0);

    // Transpose of translation matrix: translation row becomes column
    mat4 t_trans = t.transpose();
    check("mat4 transpose translation m30 == 5 (was m03)", approx(t_trans.m30, 5.0, 1e-6));
    check("mat4 transpose translation m03 == 0 (was off-diag)", approx(t_trans.m03, 0.0, 1e-6));

    // inverse of identity is identity
    mat4 inv_i = i.inverse();
    check("mat4 identity inverse m00 == 1", approx(inv_i.m00, 1.0, 1e-6));

    // singular matrix returns identity
    mat4 zero;
    mat4 inv_zero = zero.inverse();
    check("mat4 singular inverse returns identity m00 == 1", inv_zero.m00 == 1.0);
    check("mat4 singular inverse returns identity m33 == 1", inv_zero.m33 == 1.0);

    // determinant of identity is 1
    float64 det_i = i.determinant();
    check("mat4 identity determinant == 1", approx(det_i, 1.0, 1e-6));

    // determinant of zero is 0
    float64 det_zero = zero.determinant();
    check("mat4 zero determinant == 0", approx(det_zero, 0.0, 1e-6));

    // mul (same as operator*)
    mat4 mul_result = t.mul(s);
    mat4 op_result = t * s;
    check("mat4 mul == operator* m00", approx(mul_result.m00, op_result.m00, 1e-6));
    check("mat4 mul == operator* m03", approx(mul_result.m03, op_result.m03, 1e-6));
    check("mat4 mul == operator* m33", approx(mul_result.m33, op_result.m33, 1e-6));

    // scale (scalar multiply)
    mat4 scaled = i.scale(2.0);
    check("mat4 identity scale(2) m00 == 2", approx(scaled.m00, 2.0, 1e-6));
    check("mat4 identity scale(2) m11 == 2", approx(scaled.m11, 2.0, 1e-6));
    check("mat4 identity scale(2) m22 == 2", approx(scaled.m22, 2.0, 1e-6));
    check("mat4 identity scale(2) m33 == 2", approx(scaled.m33, 2.0, 1e-6));

    // neg (unary negate)
    mat4 neg_m = i.neg();
    check("mat4 identity neg m00 == -1", approx(neg_m.m00, -1.0, 1e-6));
    check("mat4 identity neg m11 == -1", approx(neg_m.m11, -1.0, 1e-6));

    // transform_point (applies translation)
    mat4 trans = mat4_translation(vec3(1.0, 2.0, 3.0));
    vec3 pt = vec3(10.0, 20.0, 30.0);
    vec3 pt_transformed = trans.transform_point(pt);
    check("mat4 transform_point x == 11", approx(pt_transformed.x, 11.0, 1e-6));
    check("mat4 transform_point y == 22", approx(pt_transformed.y, 22.0, 1e-6));
    check("mat4 transform_point z == 33", approx(pt_transformed.z, 33.0, 1e-6));

    // transform_vec3 (ignores translation -- use for directions)
    vec3 dir = vec3(1.0, 0.0, 0.0);
    vec3 dir_transformed = trans.transform_vec3(dir);
    check("mat4 transform_vec3 ignores translation x == 1", approx(dir_transformed.x, 1.0, 1e-6));
    check("mat4 transform_vec3 y == 2 (no translation)", approx(dir_transformed.y, 2.0, 1e-6));

    // Scale and check transform_vec3
    vec3 dir_scaled = s.transform_vec3(vec3(1.0, 1.0, 1.0));
    check("mat4 scale(2,3,4) transform_vec3 x == 2", approx(dir_scaled.x, 2.0, 1e-6));
    check("mat4 scale(2,3,4) transform_vec3 y == 3", approx(dir_scaled.y, 3.0, 1e-6));
    check("mat4 scale(2,3,4) transform_vec3 z == 4", approx(dir_scaled.z, 4.0, 1e-6));

    // transform_vec4 (full 4-component transform)
    vec4 v4 = vec4(1.0, 2.0, 3.0, 1.0);
    vec4 v4r = i.transform_vec4(v4);
    // Identity * vec4 = same
    check("mat4 identity transform_vec4 x == 1", approx(v4r.x, 1.0, 1e-6));
    check("mat4 identity transform_vec4 y == 2", approx(v4r.y, 2.0, 1e-6));
    check("mat4 identity transform_vec4 z == 3", approx(v4r.z, 3.0, 1e-6));
    check("mat4 identity transform_vec4 w == 1", approx(v4r.w, 1.0, 1e-6));

    // transform_vec4 with translation
    vec4 v4t = trans.transform_vec4(vec4(0.0, 0.0, 0.0, 1.0));
    check("mat4 trans transform_vec4 x == 1", approx(v4t.x, 1.0, 1e-6));
    check("mat4 trans transform_vec4 y == 2", approx(v4t.y, 2.0, 1e-6));
    check("mat4 trans transform_vec4 z == 3", approx(v4t.z, 3.0, 1e-6));
    check("mat4 trans transform_vec4 w == 1", approx(v4t.w, 1.0, 1e-6));
}

// ============================================================================
// 9. mat4 operators
// ============================================================================

void test_mat4_operators() {
    section("mat4 - operators");

    mat4 i = mat4_identity();
    mat4 t = mat4_translation(vec3(1.0, 2.0, 3.0));

    // a * b
    mat4 prod = t * i;
    check("mat4 t * i m03 == 1", approx(prod.m03, 1.0, 1e-6));

    // a + b
    mat4 sum = i + i;
    check("mat4 i + i m00 == 2", approx(sum.m00, 2.0, 1e-6));
    check("mat4 i + i m11 == 2", approx(sum.m11, 2.0, 1e-6));

    // a - b
    mat4 diff = i - i;
    check("mat4 i - i m00 == 0", approx(diff.m00, 0.0, 1e-6));

    // -m (unary negate)
    mat4 neg = -i;
    check("mat4 -i m00 == -1", approx(neg.m00, -1.0, 1e-6));

    // a == b
    check("mat4 i == i", i == i);
    check("mat4 i != t", !(i == t));

    // a += b
    mat4 accum = i;
    accum += i;
    check("mat4 i += i m00 == 2", approx(accum.m00, 2.0, 1e-6));

    // a -= b
    accum -= i;
    check("mat4 (i+i) -= i m00 == 1", approx(accum.m00, 1.0, 1e-6));

    // a *= b
    mat4 accum2 = t;
    accum2 *= i;
    check("mat4 t *= i m03 == 1", approx(accum2.m03, 1.0, 1e-6));
}

// ============================================================================
// 10. Common patterns
// ============================================================================

void test_common_patterns() {
    section("Common patterns");

    // --- TRS world matrix ---
    // Build: world = translation * rotation * scale
    vec3 pos = vec3(10.0, 20.0, 30.0);
    quat rot = quat_from_axis_angle(vec3(0.0, 1.0, 0.0), deg_to_rad(45.0));
    vec3 scl = vec3(2.0, 2.0, 2.0);

    mat4 world = mat4_translation(pos) * mat4_from_quat(rot) * mat4_scale(scl);
    check("TRS world matrix m03 == 10 (translation)", approx(world.m03, 10.0, 1e-6));
    check("TRS world matrix m13 == 20", approx(world.m13, 20.0, 1e-6));
    check("TRS world matrix m23 == 30", approx(world.m23, 30.0, 1e-6));

    vec3 local_pos = vec3(1.0, 0.0, 0.0);
    vec3 world_pos = world.transform_point(local_pos);
    check("TRS world_pos returns finite", is_finite(world_pos.x));

    // --- View-projection matrix ---
    vec3 camera_pos = vec3(0.0, 0.0, 10.0);
    vec3 target = vec3(0.0, 0.0, 0.0);
    vec3 up = vec3(0.0, 1.0, 0.0);

    mat4 view = mat4_look_at(camera_pos, target, up);
    mat4 proj = mat4_perspective(deg_to_rad(60.0), 16.0 / 9.0, 0.1, 1000.0);
    mat4 vp = proj * view;
    check("VP matrix returns finite", is_finite(vp.m00));

    vec3 ndc = vp.transform_point(world_pos);
    check("VP transform_point returns finite", is_finite(ndc.x));

    // --- Slerp between two orientations ---
    quat qa = quat_identity();
    quat qb = quat_from_axis_angle(vec3(0.0, 1.0, 0.0), deg_to_rad(90.0));
    float64 t_param = 0.5;
    quat qcurrent = qa.slerp(qb, t_param);
    check("Slerp between orientations w ~= cos(45deg/2)", approx(qcurrent.w, 0.92387953, 1e-6));

    vec3 facing = qcurrent.rotate(vec3(0.0, 0.0, 1.0));
    check("Slerp rotated facing returns finite", is_finite(facing.x));
}

// ============================================================================
// 11. Main -- call all test functions
// ============================================================================

int32 main() {
    print_console("=== 3D Math (quat + mat4) addon comprehensive test ===");

    test_quat_construct_default();
    test_quat_construct_explicit();
    test_quat_free_functions();
    test_quat_methods();
    test_quat_operators();

    test_mat4_construct_default_and_fields();
    test_mat4_free_functions();
    test_mat4_methods();
    test_mat4_operators();

    test_common_patterns();

    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    if (g_fail > 0) {
        return 1;
    }
    return 0;
}
