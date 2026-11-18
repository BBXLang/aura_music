#include "desktop_lyrics_window.h"

#include <objidl.h>
#include <gdiplus.h>
#include <windowsx.h>

#include <algorithm>
#include <vector>

namespace {

constexpr wchar_t kDesktopLyricsClass[] = L"AuraMusicDesktopLyricsWindow";
constexpr int kWindowWidth = 780;
constexpr int kWindowHeight = 138;

void AddRoundedRectPath(Gdiplus::GraphicsPath& path, const Gdiplus::RectF& rect,
                        float radius) {
  const float d = radius * 2.0f;
  path.AddArc(rect.X, rect.Y, d, d, 180.0f, 90.0f);
  path.AddArc(rect.X + rect.Width - d, rect.Y, d, d, 270.0f, 90.0f);
  path.AddArc(rect.X + rect.Width - d, rect.Y + rect.Height - d, d, d, 0.0f,
              90.0f);
  path.AddArc(rect.X, rect.Y + rect.Height - d, d, d, 90.0f, 90.0f);
  path.CloseFigure();
}

std::wstring GetFontPath() {
  wchar_t exe_path[MAX_PATH]{};
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::wstring dir(exe_path);
  const auto slash = dir.find_last_of(L"\\/");
  if (slash != std::wstring::npos) {
    dir = dir.substr(0, slash);
  }
  return dir + L"\\data\\flutter_assets\\assets\\fonts\\HarmonyOS_Sans_SC.ttf";
}

}  // namespace

DesktopLyricsWindow::DesktopLyricsWindow(ActionCallback on_action)
    : on_action_(std::move(on_action)) {
  Gdiplus::GdiplusStartupInput input;
  if (Gdiplus::GdiplusStartup(&gdiplus_token_, &input, nullptr) ==
      Gdiplus::Ok) {
    gdiplus_started_ = true;
  }
}

DesktopLyricsWindow::~DesktopLyricsWindow() {
  Destroy();
  if (gdiplus_started_) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_started_ = false;
  }
}

std::wstring DesktopLyricsWindow::Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return L"";
  const int len =
      MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                          nullptr, 0);
  if (len <= 0) return L"";
  std::wstring wide(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), len);
  return wide;
}

void DesktopLyricsWindow::EnsureCreated() {
  if (hwnd_) return;

  WNDCLASSEXW wc{};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.lpfnWndProc = DesktopLyricsWindow::WndProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  wc.lpszClassName = kDesktopLyricsClass;
  RegisterClassExW(&wc);

  RECT work_area{};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
  const int screen_w = work_area.right - work_area.left;
  const int x = work_area.left + (screen_w - kWindowWidth) / 2;
  const int y = work_area.bottom - kWindowHeight - 28;

  hwnd_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kDesktopLyricsClass, L"AuraMusic Lyrics", WS_POPUP, x, y, kWindowWidth,
      kWindowHeight, nullptr, nullptr, GetModuleHandleW(nullptr), this);
}

void DesktopLyricsWindow::Destroy() {
  if (hwnd_) {
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
  visible_ = false;
}

void DesktopLyricsWindow::SetEnabled(bool enabled) {
  visible_ = enabled;
  if (!enabled) {
    if (hwnd_) {
      ShowWindow(hwnd_, SW_HIDE);
    }
    return;
  }
  EnsureCreated();
  if (hwnd_) {
    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    Render();
  }
}

void DesktopLyricsWindow::SetLyricState(const std::string& current_line,
                                        const std::string& next_line,
                                        double progress, bool is_playing) {
  if (!current_line.empty()) {
    current_line_ = Utf8ToWide(current_line);
  }
  next_line_ = Utf8ToWide(next_line);
  progress_ = std::clamp(progress, 0.0, 1.0);
  is_playing_ = is_playing;
  if (visible_ && hwnd_) {
    Render();
  }
}

void DesktopLyricsWindow::SetIsPlaying(bool is_playing) {
  is_playing_ = is_playing;
  if (visible_ && hwnd_) {
    Render();
  }
}

void DesktopLyricsWindow::Render() {
  if (!hwnd_ || !gdiplus_started_) return;

  BITMAPINFO bmi{};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = kWindowWidth;
  bmi.bmiHeader.biHeight = -kWindowHeight;  // top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  HDC screen_dc = GetDC(nullptr);
  HDC mem_dc = CreateCompatibleDC(screen_dc);
  HBITMAP dib =
      CreateDIBSection(screen_dc, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (!dib) {
    DeleteDC(mem_dc);
    ReleaseDC(nullptr, screen_dc);
    return;
  }
  HGDIOBJ old_bmp = SelectObject(mem_dc, dib);

  {
    Gdiplus::Graphics g(mem_dc);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
    g.Clear(Gdiplus::Color(0, 0, 0, 0));

    // Load HarmonyOS Sans SC font if bundled.
    Gdiplus::PrivateFontCollection private_fonts;
    const std::wstring font_path = GetFontPath();
    bool has_custom_font = false;
    if (GetFileAttributesW(font_path.c_str()) != INVALID_FILE_ATTRIBUTES) {
      if (private_fonts.AddFontFile(font_path.c_str()) == Gdiplus::Ok &&
          private_fonts.GetFamilyCount() > 0) {
        has_custom_font = true;
      }
    }
    Gdiplus::FontFamily custom_family;
    int found = 0;
    if (has_custom_font) {
      private_fonts.GetFamilies(1, &custom_family, &found);
    }
    const Gdiplus::FontFamily fallback_family(L"Microsoft YaHei UI");
    const Gdiplus::FontFamily& family =
        (has_custom_font && found > 0) ? custom_family : fallback_family;

    // Draw hover control capsule when hovered (and not locked) or show small
    // lock button on hover even when locked.
    if (hovered_) {
      Gdiplus::GraphicsPath bg_path;
      AddRoundedRectPath(
          bg_path,
          Gdiplus::RectF(4.0f, 4.0f, static_cast<float>(kWindowWidth - 8),
                         static_cast<float>(kWindowHeight - 8)),
          24.0f);
      Gdiplus::SolidBrush bg_brush(Gdiplus::Color(178, 15, 23, 42));
      Gdiplus::Pen border_pen(Gdiplus::Color(70, 255, 255, 255), 1.0f);
      g.FillPath(&bg_brush, &bg_path);
      g.DrawPath(&border_pen, &bg_path);

      // Top control buttons: Prev, Play/Pause, Next, Lock, Close
      const wchar_t* labels[5] = {
          L"|<", is_playing_ ? L"||" : L"▶", L">|", locked_ ? L"🔓" : L"🔒", L"✕",
      };
      const int total_w = 5 * 36 + 4 * 8;
      int start_x = (kWindowWidth - total_w) / 2;
      Gdiplus::Font btn_font(&family, 11.0f, Gdiplus::FontStyleBold,
                             Gdiplus::UnitPoint);
      Gdiplus::StringFormat btn_fmt;
      btn_fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
      btn_fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);

      for (int i = 0; i < 5; ++i) {
        if (locked_ && i != 3) {
          btn_rects_[i] = {0, 0, 0, 0};
          start_x += 44;
          continue;
        }
        RECT r = {start_x, 10, start_x + 36, 36};
        btn_rects_[i] = r;
        Gdiplus::RectF rf(static_cast<float>(r.left), static_cast<float>(r.top),
                          36.0f, 26.0f);
        Gdiplus::GraphicsPath pill;
        AddRoundedRectPath(pill, rf, 10.0f);
        Gdiplus::SolidBrush pill_brush(
            hover_btn_ == i ? Gdiplus::Color(90, 255, 255, 255)
                            : Gdiplus::Color(38, 255, 255, 255));
        g.FillPath(&pill_brush, &pill);
        Gdiplus::SolidBrush txt_brush(Gdiplus::Color(240, 255, 255, 255));
        g.DrawString(labels[i], -1, &btn_font, rf, &btn_fmt, &txt_brush);
        start_x += 44;
      }
    } else {
      for (int i = 0; i < 5; ++i) btn_rects_[i] = {0, 0, 0, 0};
    }

    // Measure primary lyric line so karaoke gradient maps strictly to text width.
    Gdiplus::Font main_font(&family, 24.0f, Gdiplus::FontStyleBold,
                            Gdiplus::UnitPoint);
    Gdiplus::StringFormat center_fmt;
    center_fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
    center_fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
    center_fmt.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
    center_fmt.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);

    Gdiplus::RectF main_rect(24.0f, 38.0f,
                             static_cast<float>(kWindowWidth - 48), 54.0f);
    Gdiplus::RectF measured;
    g.MeasureString(current_line_.c_str(), -1, &main_font,
                    Gdiplus::PointF(0, 0), &measured);

    // Draw soft outline shadow for readability over bright wallpapers.
    Gdiplus::SolidBrush shadow_brush(Gdiplus::Color(190, 0, 0, 0));
    const float offsets[4][2] = {{-1.5f, 0}, {1.5f, 0}, {0, -1.5f}, {0, 2.0f}};
    for (const auto& off : offsets) {
      Gdiplus::RectF s_rect = main_rect;
      s_rect.X += off[0];
      s_rect.Y += off[1];
      g.DrawString(current_line_.c_str(), -1, &main_font, s_rect, &center_fmt,
                   &shadow_brush);
    }

    // Karaoke left-to-right sweep brush across the measured lyric span.
    const float text_w = (std::max)(20.0f, (std::min)(measured.Width, main_rect.Width));
    const float left_x = (kWindowWidth - text_w) * 0.5f;
    const float p = static_cast<float>(std::clamp(progress_, 0.0, 1.0));
    const float p2 = (std::min)(1.0f, p + 0.02f);

    Gdiplus::LinearGradientBrush karaoke_brush(
        Gdiplus::PointF(left_x, 0.0f),
        Gdiplus::PointF(left_x + text_w, 0.0f),
        Gdiplus::Color(255, 56, 189, 248),
        Gdiplus::Color(255, 255, 255, 255));
    Gdiplus::Color colors[4] = {
        Gdiplus::Color(255, 56, 189, 248),
        Gdiplus::Color(255, 168, 85, 247),
        Gdiplus::Color(255, 255, 255, 255),
        Gdiplus::Color(255, 255, 255, 255),
    };
    Gdiplus::REAL stops[4] = {0.0f, p, p2, 1.0f};
    karaoke_brush.SetInterpolationColors(colors, stops, 4);

    g.DrawString(current_line_.c_str(), -1, &main_font, main_rect, &center_fmt,
                 &karaoke_brush);

    // Draw secondary next lyric line below.
    if (!next_line_.empty()) {
      Gdiplus::Font sub_font(&family, 13.5f, Gdiplus::FontStyleRegular,
                             Gdiplus::UnitPoint);
      Gdiplus::RectF sub_rect(36.0f, 92.0f,
                              static_cast<float>(kWindowWidth - 72), 32.0f);
      Gdiplus::RectF sub_shadow = sub_rect;
      sub_shadow.Y += 1.5f;
      Gdiplus::SolidBrush sub_shadow_brush(Gdiplus::Color(150, 0, 0, 0));
      g.DrawString(next_line_.c_str(), -1, &sub_font, sub_shadow, &center_fmt,
                   &sub_shadow_brush);

      Gdiplus::SolidBrush sub_brush(Gdiplus::Color(210, 226, 232, 240));
      g.DrawString(next_line_.c_str(), -1, &sub_font, sub_rect, &center_fmt,
                   &sub_brush);
    }
  }

  POINT pt_src{0, 0};
  SIZE wnd_size{kWindowWidth, kWindowHeight};
  BLENDFUNCTION blend{AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  UpdateLayeredWindow(hwnd_, screen_dc, nullptr, &wnd_size, mem_dc, &pt_src, 0,
                      &blend, ULW_ALPHA);

  SelectObject(mem_dc, old_bmp);
  DeleteObject(dib);
  DeleteDC(mem_dc);
  ReleaseDC(nullptr, screen_dc);
}

LRESULT CALLBACK DesktopLyricsWindow::WndProc(HWND hwnd, UINT msg, WPARAM wparam,
                                              LPARAM lparam) {
  DesktopLyricsWindow* self = nullptr;
  if (msg == WM_NCCREATE) {
    auto* cs = reinterpret_cast<CREATESTRUCTW*>(lparam);
    self = reinterpret_cast<DesktopLyricsWindow*>(cs->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  } else {
    self = reinterpret_cast<DesktopLyricsWindow*>(
        GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  }
  if (self) {
    return self->HandleMessage(hwnd, msg, wparam, lparam);
  }
  return DefWindowProcW(hwnd, msg, wparam, lparam);
}

LRESULT DesktopLyricsWindow::HandleMessage(HWND hwnd, UINT msg, WPARAM wparam,
                                           LPARAM lparam) {
  switch (msg) {
    case WM_MOUSEMOVE: {
      if (!tracking_leave_) {
        TRACKMOUSEEVENT tme{sizeof(TRACKMOUSEEVENT), TME_LEAVE, hwnd, 0};
        TrackMouseEvent(&tme);
        tracking_leave_ = true;
      }
      POINT pt{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      int new_hover = -1;
      for (int i = 0; i < 5; ++i) {
        if (PtInRect(&btn_rects_[i], pt)) {
          new_hover = i;
          break;
        }
      }
      if (!hovered_ || new_hover != hover_btn_) {
        hovered_ = true;
        hover_btn_ = new_hover;
        Render();
      }
      return 0;
    }
    case WM_MOUSELEAVE: {
      tracking_leave_ = false;
      hovered_ = false;
      hover_btn_ = -1;
      Render();
      return 0;
    }
    case WM_LBUTTONDOWN: {
      POINT pt{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      for (int i = 0; i < 5; ++i) {
        if (PtInRect(&btn_rects_[i], pt)) {
          if (i == 3) {
            locked_ = !locked_;
            Render();
            return 0;
          }
          const char* actions[5] = {"prev", "togglePlay", "next", "", "close"};
          if (on_action_ && actions[i][0] != '\0') {
            on_action_(actions[i]);
          }
          return 0;
        }
      }
      if (!locked_) {
        ReleaseCapture();
        SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
      }
      return 0;
    }
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
  }
  return DefWindowProcW(hwnd, msg, wparam, lparam);
}
