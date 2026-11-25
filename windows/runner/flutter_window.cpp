#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

#include <algorithm>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  flutter::MethodChannel<> mini_player(
      flutter_controller_->engine()->messenger(), "apexduanju/mini_player",
      &flutter::StandardMethodCodec::GetInstance());
  mini_player.SetMethodCallHandler([this](const auto& call, auto result) {
    bool ok;
    if (call.method_name() == "enter" && call.arguments() &&
        std::holds_alternative<bool>(*call.arguments())) {
      ok = EnterMiniPlayer(std::get<bool>(*call.arguments()));
    } else if (call.method_name() == "exit") {
      ok = ExitMiniPlayer();
    } else if (call.method_name() == "drag" && saved_placement_.length != 0) {
      ReleaseCapture();
      ok = PostMessage(GetHandle(), WM_SYSCOMMAND, SC_MOVE | HTCAPTION, 0) != 0;
    } else {
      result->NotImplemented();
      return;
    }
    if (ok) {
      result->Success();
    } else {
      result->Error("window", "Could not change mini player mode");
    }
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

bool FlutterWindow::EnterMiniPlayer(bool portrait) {
  if (saved_placement_.length != 0) return true;
  HWND hwnd = GetHandle();
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (!GetMonitorInfo(monitor, &info) || !GetWindowPlacement(hwnd, &placement)) {
    return false;
  }
  saved_placement_ = placement;
  mini_portrait_ = portrait;
  saved_style_ = GetWindowLongPtr(hwnd, GWL_STYLE);
  was_topmost_ = (GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
  if (IsZoomed(hwnd)) ShowWindow(hwnd, SW_RESTORE);
  const LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  SetWindowLongPtr(hwnd, GWL_STYLE,
                   (style & ~WS_OVERLAPPEDWINDOW) | WS_POPUP | WS_THICKFRAME);
  const int dpi = static_cast<int>(FlutterDesktopGetDpiForMonitor(monitor));
  const int margin = MulDiv(16, dpi, 96);
  const SIZE size = mini_sizes_[portrait];
  const int width = (std::min)(MulDiv(size.cx, dpi, 96),
                               int(info.rcWork.right - info.rcWork.left) - 2 * margin);
  const int height = (std::min)(MulDiv(size.cy, dpi, 96),
                                int(info.rcWork.bottom - info.rcWork.top) - 2 * margin);
  if (SetWindowPos(hwnd, HWND_TOPMOST, info.rcWork.right - width - margin,
                   info.rcWork.bottom - height - margin, width, height,
                   SWP_FRAMECHANGED | SWP_NOACTIVATE)) {
    return true;
  }
  ExitMiniPlayer();
  return false;
}

bool FlutterWindow::ExitMiniPlayer() {
  if (saved_placement_.length == 0) return true;
  HWND hwnd = GetHandle();
  const WINDOWPLACEMENT placement = saved_placement_;
  saved_placement_ = {};
  SetWindowLongPtr(hwnd, GWL_STYLE, saved_style_ & ~WS_MAXIMIZE);
  if (!SetWindowPlacement(hwnd, &placement) ||
      !SetWindowPos(hwnd, was_topmost_ ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                    SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED)) {
    saved_placement_ = placement;
    return false;
  }
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (saved_placement_.length != 0) {
    // Keep the native sizing border even when the player entered from fullscreen.
    if (message == WM_NCCALCSIZE || message == WM_NCHITTEST) {
      return DefWindowProc(hwnd, message, wparam, lparam);
    }
    if (message == WM_GETMINMAXINFO) {
      const UINT dpi = FlutterDesktopGetDpiForHWND(hwnd);
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize = {MulDiv(208, dpi, 96), MulDiv(156, dpi, 96)};
      return 0;
    }
    if (message == WM_EXITSIZEMOVE) {
      RECT rect;
      if (GetWindowRect(hwnd, &rect)) {
        const UINT dpi = FlutterDesktopGetDpiForHWND(hwnd);
        mini_sizes_[mini_portrait_] = {MulDiv(rect.right - rect.left, 96, dpi),
                                      MulDiv(rect.bottom - rect.top, 96, dpi)};
      }
    }
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
