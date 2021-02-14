//
//  HSSpeedEditorManager.h
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

@import Foundation;
@import IOKit;
@import IOKit.hid;

@import LuaSkin;

//#import "HSSpeedEditorDevice.h"
#import "speededitor.h"

@interface HSSpeedEditorManager : NSObject
@property (nonatomic, strong) id ioHIDManager;
@property (nonatomic, strong) NSMutableArray *devices;
@property (nonatomic) int discoveryCallbackRef;

- (id)init;
- (void)doGC;
- (BOOL)startHIDManager;
- (BOOL)stopHIDManager;
//- (HSSpeedEditorDevice*)deviceDidConnect:(IOHIDDeviceRef)device;
- (void)deviceDidDisconnect:(IOHIDDeviceRef)device;

@end
