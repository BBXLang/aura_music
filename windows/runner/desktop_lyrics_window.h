#ifndef RUNNER_DESKTOP_LYRICS_WINDOW_H_
#define RUNNER_DESKTOP_LYRICS_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

/// Native Win32 topmost, per-pixel translucent desktop lyrics overlay window
/// that renders outside the Flutter app window across the Windows desktop.
class DesktopLyricsWindow {
 public:
  using ActionCallback = std::function<void(const std::string& action)>;

  explicit DesktopLyricsWindow(ActionCallback on_action);
  ~DesktopLyricsWindow();

  void SetEnabled(bool enabled);
  void SetLyricState(const std::string& current_line,
                     const std::string& next_line,
                     double progress,
                     bool is_playing);
  void SetIsPlaying(bool is_playing);

 private:
  struct ButtonHit {
    RECT rect;
    std::string action;
  };

  void EnsureCreated();
  void Destroy();
  void Render();
  static std::wstring Utf8ToWide(const std::string& utf8);
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam,
                                  LPARAM lparam);
  LRESULT HandleMessage(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

  ActionCallback on_action_;
  HWND hwnd_ = nullptr;
  ULONG_PTR gdiplus_token_ = 0;
  bool gdiplus_started_ = false;
  bool font_loaded_ = false;
  bool has_custom_font_ = false;
  void* font_collection_ = nullptr;
  void* custom_family_ = nullptr;
  bool visible_ = false;
  bool hovered_ = false;
  bool locked_ = false;
  bool tracking_leave_ = false;
  bool is_playing_ = false;
  double progress_ = 0.0;
  std::wstring current_line_ = L"Lite Music \u684C\u9762\u6B4C\u8BCD";
  std::wstring next_line_;
  RECT btn_rects_[5]{};
  int hover_btn_ = -1;
};

#endif  // RUNNER_DESKTOP_LYRICS_WINDOW_H_
