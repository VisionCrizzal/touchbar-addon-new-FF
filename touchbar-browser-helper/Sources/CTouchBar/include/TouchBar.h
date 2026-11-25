//
//  TouchBar.h
//  touchbar-browser-helper
//
//  Created by Alexsander Akers on 2/13/17.
//  Modified by Viktor Strate Kløvedal on 07/11/2020.
//
//  Copyright © 2017 Alexsander Akers. All rights reserved.
//  https://github.com/a2/touch-baer/blob/master/TouchBarTest/TouchBar.h
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

extern void DFRElementSetControlStripPresenceForIdentifier(NSTouchBarItemIdentifier identifier, BOOL present);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL show);
extern void TouchBarHideSystemModalCloseButton(BOOL hide);

@interface NSTouchBarItem (PrivateTouchBar)
+ (void)addSystemTrayItem:(nullable NSTouchBarItem *)item;
+ (void)removeSystemTrayItem:(nullable NSTouchBarItem *)item;
@end

@interface NSTouchBar (PrivateTouchBar)
+ (void)presentSystemModalTouchBar:(nullable NSTouchBar *)touchBar placement:(long long)placement systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)presentSystemModalTouchBar:(nullable NSTouchBar *)touchBar systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(nullable NSTouchBar *)touchBar;
+ (void)minimizeSystemModalTouchBar:(nullable NSTouchBar *)touchBar;
@end

NS_ASSUME_NONNULL_END
