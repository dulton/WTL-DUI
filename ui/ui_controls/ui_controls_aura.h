// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef UI_UI_CONTROLS_UI_CONTROLS_AURA_H_
#define UI_UI_CONTROLS_UI_CONTROLS_AURA_H_
#pragma once

#include "base/callback_forward.h"
#include "ui/base/keycodes/keyboard_codes.h"
#include "ui/base/ui_export.h"
#include "ui/gfx/native_widget_types.h"
#include "ui/ui_controls/ui_controls.h"

namespace ui_controls {

// An interface to provide Aura implementation of UI control.
class UI_EXPORT UIControlsAura {
 public:
  UIControlsAura();
  virtual ~UIControlsAura();

  virtual bool SendKeyPress(gfx::NativeWindow window,
                            ui::KeyboardCode key,
                            bool control,
                            bool shift,
                            bool alt,
                            bool command) = 0;
  virtual bool SendKeyPressNotifyWhenDone(gfx::NativeWindow window,
                                          ui::KeyboardCode key,
                                          bool control,
                                          bool shift,
                                          bool alt,
                                          bool command,
                                          const base::Closure& task) = 0;

  // Simulate a mouse move. (x,y) are absolute screen coordinates.
  virtual bool SendMouseMove(long x, long y) = 0;
  virtual bool SendMouseMoveNotifyWhenDone(long x,
                                           long y,
                                           const base::Closure& task) = 0;

  // Sends a mouse down and/or up message. The click will be sent to wherever
  // the cursor currently is, so be sure to move the cursor before calling this
  // (and be sure the cursor has arrived!).
  virtual bool SendMouseEvents(MouseButton type, int state) =0;
  virtual bool SendMouseEventsNotifyWhenDone(MouseButton type, int state,
                                             const base::Closure& task) = 0;
  // Same as SendMouseEvents with BUTTON_UP | BUTTON_DOWN.
  virtual bool SendMouseClick(MouseButton type) = 0;

  // Runs |closure| after processing all pending ui events.
  virtual void RunClosureAfterAllPendingUIEvents(
      const base::Closure& closure) = 0;
};

}  // namespace ui_controls

#endif  // UI_UI_CONTROLS_UI_CONTROLS_AURA_H_
