// math3d.h — vectors, 4x4 matrices and both projection conventions.
//
// Roblox stores its view-projection matrix as 16 floats whose convention can
// differ between renderers/builds. We never assume: both interpretations are
// supported and the collector picks the one that projects a known camera-forward
// point correctly. When neither matrix convention works, the camera-direct
// projection (CFrame + FOV) takes over.

#pragma once

#include <cmath>
#include <cstddef>

struct Vec2 {
    float x = 0.0f;
    float y = 0.0f;

    Vec2() = default;
    Vec2(float x_, float y_) : x(x_), y(y_) {}
};

struct Vec3 {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vec3() = default;
    Vec3(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}

    Vec3 operator+(const Vec3& o) const { return {x + o.x, y + o.y, z + o.z}; }
    Vec3 operator-(const Vec3& o) const { return {x - o.x, y - o.y, z - o.z}; }
    Vec3 operator*(float s) const { return {x * s, y * s, z * s}; }
    Vec3& operator+=(const Vec3& o) { x += o.x; y += o.y; z += o.z; return *this; }
};

inline float dot(const Vec3& a, const Vec3& b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
inline float length_sq(const Vec3& v) { return dot(v, v); }
inline float length(const Vec3& v) { return std::sqrt(length_sq(v)); }
inline float distance(const Vec3& a, const Vec3& b) { return length(a - b); }

inline bool finite(float v) { return std::isfinite(v); }
inline bool finite(const Vec3& v) { return finite(v.x) && finite(v.y) && finite(v.z); }
inline bool finite(const Vec2& v) { return finite(v.x) && finite(v.y); }

// A 4x4 matrix stored row-major (m[row * 4 + col]), which is how Roblox keeps it.
struct Mat4 {
    float m[16]{};
};

enum class ProjectionMode : int {
    None = 0,
    RowVector = 1,   // clip = v * M
    ColumnVector = 2, // clip = M * v
    Camera = 3,      // built from CFrame + FOV
};

inline const char* projection_mode_name(ProjectionMode mode) {
    switch (mode) {
    case ProjectionMode::RowVector: return "matrix row-vector";
    case ProjectionMode::ColumnVector: return "matrix column-vector";
    case ProjectionMode::Camera: return "camera cframe";
    default: return "none";
    }
}

struct ClipResult {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float w = 0.0f;
};

inline ClipResult clip_row_vector(const Mat4& m, const Vec3& v) {
    ClipResult c;
    c.x = v.x * m.m[0] + v.y * m.m[4] + v.z * m.m[8] + m.m[12];
    c.y = v.x * m.m[1] + v.y * m.m[5] + v.z * m.m[9] + m.m[13];
    c.z = v.x * m.m[2] + v.y * m.m[6] + v.z * m.m[10] + m.m[14];
    c.w = v.x * m.m[3] + v.y * m.m[7] + v.z * m.m[11] + m.m[15];
    return c;
}

inline ClipResult clip_column_vector(const Mat4& m, const Vec3& v) {
    ClipResult c;
    c.x = m.m[0] * v.x + m.m[1] * v.y + m.m[2] * v.z + m.m[3];
    c.y = m.m[4] * v.x + m.m[5] * v.y + m.m[6] * v.z + m.m[7];
    c.z = m.m[8] * v.x + m.m[9] * v.y + m.m[10] * v.z + m.m[11];
    c.w = m.m[12] * v.x + m.m[13] * v.y + m.m[14] * v.z + m.m[15];
    return c;
}

inline bool clip_to_screen(const ClipResult& c, const Vec2& viewport, Vec2& out, bool allow_offscreen) {
    if (!finite(c.x) || !finite(c.y) || !finite(c.z) || !finite(c.w))
        return false;
    if (c.w <= 0.01f)
        return false;
    const float inv_w = 1.0f / c.w;
    const float ndc_x = c.x * inv_w;
    const float ndc_y = c.y * inv_w;
    const float ndc_z = c.z * inv_w;
    if (!finite(ndc_x) || !finite(ndc_y) || !finite(ndc_z))
        return false;
    if (ndc_z < -4.0f || ndc_z > 4.0f)
        return false;
    if (std::fabs(ndc_x) > 6.0f || std::fabs(ndc_y) > 6.0f)
        return false;
    out.x = (ndc_x * 0.5f + 0.5f) * viewport.x;
    out.y = (0.5f - ndc_y * 0.5f) * viewport.y;
    if (!allow_offscreen && (out.x < 0.0f || out.y < 0.0f || out.x > viewport.x || out.y > viewport.y))
        return false;
    return true;
}

inline bool world_to_screen(const Mat4& m, ProjectionMode mode, const Vec3& world, const Vec2& viewport,
                            Vec2& out, bool allow_offscreen = false) {
    if (viewport.x <= 0.0f || viewport.y <= 0.0f)
        return false;
    ClipResult c;
    if (mode == ProjectionMode::RowVector)
        c = clip_row_vector(m, world);
    else if (mode == ProjectionMode::ColumnVector)
        c = clip_column_vector(m, world);
    else
        return false;
    return clip_to_screen(c, viewport, out, allow_offscreen);
}

// Camera basis from the CFrame rotation matrix (row-major 3x3, as stored by
// Camera.Rotation). Roblox looks down -Z: right = column 0, up = column 1,
// forward = -column 2.
struct CameraBasis {
    Vec3 right{};
    Vec3 up{};
    Vec3 forward{};
};

inline CameraBasis make_basis(const float r[9]) {
    CameraBasis b;
    b.right = {r[0], r[3], r[6]};
    b.up = {r[1], r[4], r[7]};
    b.forward = {-r[2], -r[5], -r[8]};
    return b;
}

// Direct projection from the camera transform. Vertical FOV in degrees.
inline bool camera_to_screen(const Vec3& cam_pos, const float rot[9], float fov_deg, const Vec2& viewport,
                             const Vec3& world, Vec2& out, bool allow_offscreen = false) {
    if (viewport.x <= 0.0f || viewport.y <= 0.0f || fov_deg <= 1.0f || fov_deg >= 179.0f)
        return false;
    const CameraBasis b = make_basis(rot);
    const Vec3 rel = world - cam_pos;
    const float cx = dot(rel, b.right);
    const float cy = dot(rel, b.up);
    const float cz = dot(rel, b.forward);
    if (cz <= 0.05f)
        return false;
    const float f = 1.0f / std::tan(fov_deg * 0.5f * 3.14159265358979323846f / 180.0f);
    const float aspect = viewport.x / viewport.y;
    const float ndc_x = (cx * f / aspect) / cz;
    const float ndc_y = (cy * f) / cz;
    if (!finite(ndc_x) || !finite(ndc_y))
        return false;
    if (std::fabs(ndc_x) > 6.0f || std::fabs(ndc_y) > 6.0f)
        return false;
    out.x = (ndc_x * 0.5f + 0.5f) * viewport.x;
    out.y = (0.5f - ndc_y * 0.5f) * viewport.y;
    if (!allow_offscreen && (out.x < 0.0f || out.y < 0.0f || out.x > viewport.x || out.y > viewport.y))
        return false;
    return true;
}
