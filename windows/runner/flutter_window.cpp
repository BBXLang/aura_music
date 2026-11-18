#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::string ReadStringArg(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it != map.end()) {
    if (const auto* s = std::get_if<std::string>(&it->second)) {
      return *s;
    }
  }
  return "";
}

bool ReadBoolArg(const flutter::EncodableMap& map, const char* key,
                 bool fallback) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it != map.end()) {
    if (const auto* b = std::get_if<bool>(&it->second)) {
      return *b;
    }
  }
  return fallback;
}

double ReadDoubleArg(const flutter::EncodableMap& map, const char* key,
                     double fallback) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it != map.end()) {
    if (const auto* d = std::get_if<double>(&it->second)) {
      return *d;
    }
    if (const auto* i = std::get_if<int32_t>(&it->second)) {
      return static_cast<double>(*i);
    }
  }
  return fallback;
}

}  // namespace

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  lyrics_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.auramusic/ohos_audio",
          &flutter::StandardMethodCodec::GetInstance());

  desktop_lyrics_ = std::make_unique<DesktopLyricsWindow>(
      [this](const std::string& action) {
        if (lyrics_channel_) {
          flutter::EncodableMap args;
          args[flutter::EncodableValue("action")] =
              flutter::EncodableValue(action);
          lyrics_channel_->InvokeMethod(
              "onDesktopLyricsAction",
              std::make_unique<flutter::EncodableValue>(args));
        }
      });

  lyrics_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (call.method_name() == "setDesktopLyricsEnabled" && args) {
          const bool enabled = ReadBoolArg(*args, "enabled", false);
          const std::string cur = ReadStringArg(*args, "currentLyric");
          const std::string next = ReadStringArg(*args, "nextLyric");
          const double prog = ReadDoubleArg(*args, "progress", 0.0);
          const bool playing = ReadBoolArg(*args, "isPlaying", false);
          if (!cur.empty() || !next.empty()) {
            desktop_lyrics_->SetLyricState(cur, next, prog, playing);
          }
          desktop_lyrics_->SetEnabled(enabled);
          result->Success();
          return;
        }
        if (call.method_name() == "updateDesktopLyricLine" && args) {
          const std::string cur = ReadStringArg(*args, "line");
          const std::string next = ReadStringArg(*args, "nextLine");
          const double prog = ReadDoubleArg(*args, "progress", 0.0);
          const bool playing = ReadBoolArg(*args, "isPlaying", true);
          desktop_lyrics_->SetLyricState(cur, next, prog, playing);
          result->Success();
          return;
        }
        if (call.method_name() == "updatePlaybackState" && args) {
          const bool playing = ReadBoolArg(*args, "isPlaying", false);
          desktop_lyrics_->SetIsPlaying(playing);
          result->Success();
          return;
        }
        if (call.method_name() == "pause" || call.method_name() == "resume") {
          desktop_lyrics_->SetIsPlaying(call.method_name() == "resume");
          result->Success();
          return;
        }
        if (call.method_name() == "windowStartDrag") {
          ReleaseCapture();
          SendMessageW(GetHandle(), WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
          return;
        }
        if (call.method_name() == "windowMinimize") {
          ShowWindow(GetHandle(), SW_MINIMIZE);
          result->Success();
          return;
        }
        if (call.method_name() == "windowMaximizeOrRestore") {
          HWND h = GetHandle();
          ShowWindow(h, IsZoomed(h) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success();
          return;
        }
        if (call.method_name() == "windowClose") {
          PostMessageW(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (lyrics_channel_) {
    lyrics_channel_->SetMethodCallHandler(nullptr);
    lyrics_channel_ = nullptr;
  }
  desktop_lyrics_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
