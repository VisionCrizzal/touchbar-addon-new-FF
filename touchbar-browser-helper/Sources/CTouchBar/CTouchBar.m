#import "TouchBar.h"
#import <objc/message.h>
#import <objc/runtime.h>

static BOOL gHideSystemModalCloseButton = NO;
static __weak id gLastOverlay = nil;
static IMP gOrigUpdateCloseButton = NULL;
static IMP gOrigEscapeKeyPadding = NULL;

static void TouchBarSetBoolIvar(id obj, const char *name, BOOL value) {
  if (obj == nil) return;
  Ivar ivar = class_getInstanceVariable([obj class], name);
  if (ivar != NULL) {
    ptrdiff_t offset = ivar_getOffset(ivar);
    uint8_t *ptr = (uint8_t *)(__bridge void *)obj + offset;
    *ptr = value ? 1 : 0;
  }
}

static id TouchBarGetObjectIvar(id obj, const char *name) {
  if (obj == nil) return nil;
  Ivar ivar = class_getInstanceVariable([obj class], name);
  if (ivar == NULL) return nil;
  return object_getIvar(obj, ivar);
}

static void tb_swizzled_updateCloseButton(id self, SEL _cmd) {
  gLastOverlay = self;
  if (gHideSystemModalCloseButton) {
    TouchBarSetBoolIvar(self, "_showsCloseWhenInactive", NO);
  }

  if (gOrigUpdateCloseButton != NULL) {
    ((void (*)(id, SEL))gOrigUpdateCloseButton)(self, _cmd);
  }

  if (gHideSystemModalCloseButton) {
    id escViewer = TouchBarGetObjectIvar(self, "_escKeyViewer");
    if ([escViewer isKindOfClass:[NSStackView class]]) {
      NSStackView *stack = (NSStackView *)escViewer;
      stack.detachesHiddenViews = YES;
      for (NSView *subview in stack.subviews) {
        subview.hidden = YES;
      }
      stack.hidden = YES;
    } else if ([escViewer isKindOfClass:[NSView class]]) {
      ((NSView *)escViewer).hidden = YES;
    }

    id closeItem = TouchBarGetObjectIvar(self, "_systemCloseButtonItem");
    if ([closeItem isKindOfClass:[NSTouchBarItem class]]) {
      ((NSTouchBarItem *)closeItem).view.hidden = YES;
    }

    id colorView = TouchBarGetObjectIvar(self, "_colorView");
    if ([colorView isKindOfClass:[NSView class]]) {
      [(NSView *)colorView setNeedsLayout:YES];
    }
  }
}

static double tb_swizzled_escapeKeyPaddingForCloseButton(id self, SEL _cmd, BOOL isForCloseButton) {
  if (gHideSystemModalCloseButton && isForCloseButton) {
    return 0.0;
  }
  if (gOrigEscapeKeyPadding != NULL) {
    return ((double (*)(id, SEL, BOOL))gOrigEscapeKeyPadding)(self, _cmd, isForCloseButton);
  }
  return 0.0;
}

static void TouchBarInstallCloseButtonHooks(void) {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class overlayCls = NSClassFromString(@"NSSystemModalTouchBarOverlay");
    if (overlayCls != Nil) {
      SEL updateSel = NSSelectorFromString(@"_updateCloseButton");
      Method updateMethod = class_getInstanceMethod(overlayCls, updateSel);
      if (updateMethod != NULL) {
        gOrigUpdateCloseButton = method_setImplementation(updateMethod, (IMP)tb_swizzled_updateCloseButton);
      }
    }

    Class rowCls = NSClassFromString(@"_NSFunctionRow");
    if (rowCls != Nil) {
      SEL padSel = NSSelectorFromString(@"escapeKeyPaddingForCloseButton:");
      Method padMethod = class_getInstanceMethod(rowCls, padSel);
      if (padMethod != NULL) {
        gOrigEscapeKeyPadding = method_setImplementation(padMethod, (IMP)tb_swizzled_escapeKeyPaddingForCloseButton);
      }
    }
  });
}

void TouchBarHideSystemModalCloseButton(BOOL hide) {
  TouchBarInstallCloseButtonHooks();
  gHideSystemModalCloseButton = hide;
  DFRSystemModalShowsCloseBoxWhenFrontMost(!hide);

  id overlay = gLastOverlay;
  if (overlay != nil) {
    TouchBarSetBoolIvar(overlay, "_showsCloseWhenInactive", !hide);
    SEL updateSel = NSSelectorFromString(@"_updateCloseButton");
    if ([overlay respondsToSelector:updateSel]) {
      ((void (*)(id, SEL))objc_msgSend)(overlay, updateSel);
    }
  }
}
