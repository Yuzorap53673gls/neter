// overlay.h — two-window DX11/ImGui overlay.
//
// render window: click-through, draws ESP + panel.
// proxy window:  invisible top-level window covering only the panel, receives
//                mouse input and forwards it to ImGui.

#pragma once

#include <cstdint>
#include <windows.h>

#include <d3d11.h>
#include <imgui.h>

#include "settings.h"

struct IDCompositionDevice;
struct IDCompositionTarget;
struct IDCompositionVisual;

class Overlay {
public:
    bool init(HINSTANCE instance);
    void shutdown();

    // Processes pending window messages. Returns false when WM_QUIT arrives.
    bool pump();

    // Tracks the target process window and keeps the overlay over its client
    // area. Safe to call every frame.
    void follow(uint32_t pid);

    // Starts an ImGui frame. Returns false when there is nothing to render
    // (target minimized or renderer not ready); call end_frame only if true.
    bool begin_frame();

    // Renders ImGui draw data, presents the swapchain and repositions the input
    // proxy over the current panel bounds.
    void end_frame(const PanelState& panel_state, bool panel_visible);

    void set_panel_visible(bool visible);
    bool panel_visible() const { return panel_visible_; }

    ImVec2 display_size() const;
    ImVec2 client_origin_screen() const;
    float ui_scale() const { return ui_scale_; }

    uint32_t tracked_pid() const { return tracked_pid_; }
    HWND target_window() const { return target_hwnd_; }
    bool overlay_visible() const { return render_shown_; }

private:
    struct InputState {
        float mouse_x = -FLT_MAX;
        float mouse_y = -FLT_MAX;
        bool down[3] = {};
        int wheel = 0;
    };

    bool create_device();
    bool create_windows(HINSTANCE instance);
    void load_fonts();
    void destroy_device();
    void destroy_windows();
    bool resize_swapchain(uint32_t width, uint32_t height);
    void update_window_rect();
    void place_proxy(const PanelState& panel_state, bool panel_visible);
    void hide_proxy();
    void push_input();
    void clear_input();
    void on_proxy_mouse(uint32_t message, WPARAM wparam, LPARAM lparam);
    HWND find_target_window(uint32_t pid) const;

    static LRESULT CALLBACK render_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
    static LRESULT CALLBACK proxy_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    HINSTANCE instance_ = nullptr;
    HWND render_hwnd_ = nullptr;
    HWND proxy_hwnd_ = nullptr;
    HWND target_hwnd_ = nullptr;
    uint32_t tracked_pid_ = 0;
    uint64_t next_window_scan_ = 0;

    ID3D11Device* device_ = nullptr;
    ID3D11DeviceContext* context_ = nullptr;
    IDXGISwapChain* swapchain_ = nullptr;
    ID3D11RenderTargetView* render_target_ = nullptr;
    IDCompositionDevice* dcomp_device_ = nullptr;
    IDCompositionTarget* dcomp_target_ = nullptr;
    IDCompositionVisual* dcomp_visual_ = nullptr;

    RECT window_rect_{};
    uint32_t width_ = 0;
    uint32_t height_ = 0;
    RECT proxy_rect_{};
    bool proxy_visible_ = false;
    bool panel_visible_ = true;
    bool render_shown_ = false;
    bool imgui_ready_ = false;
    bool in_frame_ = false;
    bool tracking_mouse_ = false;
    float ui_scale_ = 1.0f;

    InputState input_;
    bool sent_down_[3] = {};
    float sent_mouse_x_ = -FLT_MAX;
    float sent_mouse_y_ = -FLT_MAX;
    bool sent_mouse_valid_ = false;
    int present_failures_ = 0;
    uint64_t last_present_fail_log_ = 0;
    bool present_logged_ = false;
};
