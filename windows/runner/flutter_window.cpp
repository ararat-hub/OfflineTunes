#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  hotkeys_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "offlinetunes/hotkeys",
      &flutter::StandardMethodCodec::GetInstance());
  hotkeys_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "bind") {
      result->NotImplemented();
      return;
    }
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("invalid_arguments");
      return;
    }
    auto integer = [arguments](const char* field) {
      auto found = arguments->find(flutter::EncodableValue(field));
      return found == arguments->end() ? nullptr
          : std::get_if<int32_t>(&found->second);
    };
    const auto* id = integer("id");
    const auto* key = integer("key");
    const auto* modifiers = integer("modifiers");
    if (!id || !key || !modifiers || *id < 0 ||
        static_cast<size_t>(*id) >= bindings_.size()) {
      result->Error("invalid_arguments");
      return;
    }
    result->Success(flutter::EncodableValue(
        BindHotkey(*id, static_cast<UINT>(*modifiers), static_cast<UINT>(*key))));
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
  if (hotkeys_) {
    hotkeys_->SetMethodCallHandler(nullptr);
    hotkeys_.reset();
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

bool FlutterWindow::BindHotkey(int id, UINT modifiers, UINT key) {
  const bool valid_key = (key >= '0' && key <= '9') ||
                         (key >= 'A' && key <= 'Z') ||
                         (key >= VK_F1 && key <= VK_F11);
  if (key && (!valid_key || (modifiers != 3 && modifiers != 5 &&
                             modifiers != 6 && modifiers != 7))) {
    return false;
  }
  const HWND hwnd = GetHandle();
  if (!hwnd) return false;
  auto& current = bindings_[id];
  const auto previous = current;
  if (previous && previous->first == modifiers && previous->second == key) {
    return true;
  }
  if (current) {
    if (!UnregisterHotKey(hwnd, id)) return false;
    current.reset();
  }
  if (!key) return true;
  if (RegisterHotKey(hwnd, id, modifiers | MOD_NOREPEAT, key)) {
    current = std::make_pair(modifiers, key);
    return true;
  }
  if (previous && RegisterHotKey(hwnd, id, previous->first | MOD_NOREPEAT,
                                 previous->second)) {
    current = previous;
  }
  return false;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_HOTKEY && hotkeys_ && wparam < bindings_.size() &&
      bindings_[wparam]) {
    hotkeys_->InvokeMethod("pressed", std::make_unique<flutter::EncodableValue>(
        static_cast<int32_t>(wparam)));
    return 0;
  }
  if (message == WM_DESTROY) {
    for (size_t id = 0; id < bindings_.size(); ++id) {
      if (bindings_[id]) UnregisterHotKey(hwnd, static_cast<int>(id));
      bindings_[id].reset();
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
