
/*
 * Copyright 2006 The Android Open Source Project
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */


#ifndef SkDrawBlur_DEFINED
#define SkDrawBlur_DEFINED

#include "SkPaintParts.h"
#include "SkBlurMaskFilter.h"

class SkDrawBlur : public SkDrawMaskFilter {
    DECLARE_DRAW_MEMBER_INFO(Blur);
    SkDrawBlur();
    virtual SkMaskFilter* getMaskFilter();
protected:
    SkScalar radius;
    int /*SkBlurMaskFilter::BlurStyle*/ blurStyle;
};

#endif // SkDrawBlur_DEFINED

