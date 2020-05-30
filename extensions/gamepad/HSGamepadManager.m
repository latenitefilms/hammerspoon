//
//  HSGamepadManager.m
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSGamepadManager.h"

#define NSSTR(e) ((NSString *)CFSTR(e))

#pragma mark - IOKit C callbacks

static char *inputBuffer = NULL;

static void HIDReport(void* deviceRef, IOReturn result, void* sender, IOHIDReportType type, uint32_t reportID, uint8_t *report,CFIndex reportLength) {
    
    NSLog(@"HIDReport triggered");
    
    //HSGamepadDevice *device = (__bridge HSGamepadDevice*)deviceRef;
    //NSMutableArray* buttonReport = [NSMutableArray arrayWithCapacity:device.keyCount+1];

    // We need an unused button at slot zero - all our uses of these arrays are one-indexed
    //[buttonReport setObject:[NSNumber numberWithInt:0] atIndexedSubscript:0];

    /*
    for(int p=1; p <= device.keyCount; p++) {
        [buttonReport setObject:@0 atIndexedSubscript:p];
    }
     */

    /*
    uint8_t *start = report + device.dataKeyOffsxet;
    for(int button=1; button <= device.keyCount; button ++) {
        NSNumber* val = [NSNumber numberWithInt:start[button-1]];
        int translatedButton = [device transformKeyIndex:button];
        [buttonReport setObject:val atIndexedSubscript:translatedButton];
    }
    [device deviceDidSendInput:buttonReport];
     */
}

static void gamepadAction(void *ctx, IOReturn inResult, void *inSender, IOHIDValueRef value) {
    NSLog(@"Gamepad talked!");
    IOHIDElementRef element = IOHIDValueGetElement(value);
    NSLog(@"Element: %@", element);
    long elementValue = IOHIDValueGetIntegerValue(value);
    NSLog(@"Element value: %li", elementValue);
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    NSLog(@"connect: %p:%p", context, (void *)device);
    HSGamepadManager *manager = (__bridge HSGamepadManager *)context;
    
    /*
    HSGamepadDevice *deviceId = [manager deviceDidConnect:device];
    if (deviceId) {
        IOHIDDeviceRegisterInputReportCallback(device, (uint8_t*)inputBuffer, 1024, HIDReport, (void*)deviceId);
        //NSLog(@"Added value callback to new IOKit device %p for Deck Device %p", (void *)device, (__bridge void*)deviceId);
    }
     */
    
    IOHIDDeviceRegisterInputValueCallback((void *)device,
                                          gamepadAction,
                                          (__bridge void * _Nullable)(manager));
}

static void HIDdisconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    NSLog(@"disconnect: %p", (void *)device);
    HSGamepadManager *manager = (__bridge HSGamepadManager *)context;
    [manager deviceDidDisconnect:device];
    IOHIDDeviceRegisterInputValueCallback(device, NULL, NULL);
}

#pragma mark - Gamepad Manager implementation
@implementation HSGamepadManager

- (id)init {
    self = [super init];
    if (self) {
        self.devices = [[NSMutableArray alloc] initWithCapacity:5];
        self.discoveryCallbackRef = LUA_NOREF;
        inputBuffer = malloc(1024);

        // Create a HID device manager
        self.ioHIDManager = CFBridgingRelease(IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone));
        //NSLog(@"Created HID Manager: %p", (void *)self.ioHIDManager);

        // Configure the HID manager to match against Gamepad devices
        NSString *deviceUsagePageKey = @(kIOHIDDeviceUsagePageKey);
        NSString *deviceUsageKey = @(kIOHIDDeviceUsageKey);

        NSDictionary *matchJoystick             = @{deviceUsagePageKey:  @(kHIDPage_GenericDesktop),
                                                    deviceUsageKey: @(kHIDUsage_GD_Joystick) };
        NSDictionary *matchGamePad              = @{deviceUsagePageKey:  @(kHIDPage_GenericDesktop),
                                                    deviceUsageKey: @(kHIDUsage_GD_GamePad) };
        NSDictionary *matchMultiAxisController  = @{deviceUsagePageKey: @(kHIDPage_GenericDesktop),
                                                    deviceUsageKey: @(kHIDUsage_GD_MultiAxisController) };
        
        IOHIDManagerSetDeviceMatchingMultiple((__bridge IOHIDManagerRef)self.ioHIDManager,
                                              (__bridge CFArrayRef)@[matchJoystick,
                                                                     matchGamePad,
                                                                     matchMultiAxisController]);

        // Add our callbacks for relevant events
        IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                                   HIDconnect,
                                                   (__bridge void*)self);
        IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                                  HIDdisconnect,
                                                  (__bridge void*)self);

        // Start our HID manager
        IOHIDManagerScheduleWithRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager,
                                        CFRunLoopGetCurrent(),
                                        kCFRunLoopDefaultMode);
        
    }
    return self;
}

- (void)doGC {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        // Something is wrong and the manager doesn't exist, so just bail
        return;
    }

    // Remove our callbacks
    IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);
    IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);

    // Remove our HID manager from the runloop
    IOHIDManagerUnscheduleFromRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    // Deallocate the HID manager
    self.ioHIDManager = nil;

    if (inputBuffer) {
        free(inputBuffer);
    }
}

- (BOOL)startHIDManager {
    IOReturn tIOReturn = IOHIDManagerOpen((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

- (BOOL)stopHIDManager {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        return YES;
    }

    IOReturn tIOReturn = IOHIDManagerClose((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

/*
- (HSGamepadDevice*)deviceDidConnect:(IOHIDDeviceRef)device {
    NSNumber *vendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *productID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    
    
    NSLog(@"vendorID: %@", vendorID);
    NSLog(@"productID: %@", productID);
    
    return nil;
    

    if (vendorID.intValue != USB_VID_ELGATO) {
        NSLog(@"deviceDidConnect from unknown vendor: %d", vendorID.intValue);
        return nil;
    }

    HSGamepadDevice *deck = nil;

    switch (productID.intValue) {
        case USB_PID_STREAMDECK_ORIGINAL:
            deck = [[HSGamepadDeviceOriginal alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_MINI:
            deck = [[HSGamepadDeviceMini alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_XL:
            deck = [[HSGamepadDeviceXL alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_ORIGINAL_V2:
            deck = [[HSGamepadDeviceOriginalV2 alloc] initWithDevice:device manager:self];
            break;

        default:
            NSLog(@"deviceDidConnect from unknown device: %d", productID.intValue);
            break;
    }
    if (!deck) {
        NSLog(@"deviceDidConnect: no HSGamepadDevice was created, ignoring");
        return nil;
    }
    [deck initialiseCaches];
    [self.devices addObject:deck];

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);
    if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
        [skin logWarn:@"hs.gamepad detected a device connecting, but no discovery callback has been set. See hs.gamepad.discoveryCallback()"];
    } else {
        [skin pushLuaRef:gamepadRefTable ref:self.discoveryCallbackRef];
        lua_pushboolean(skin.L, 1);
        [skin pushNSObject:deck];
        [skin protectedCallAndError:@"hs.gamepad:deviceDidConnect" nargs:2 nresults:0];
    }

    //NSLog(@"Created deck device: %p", (__bridge void*)deviceId);
    //NSLog(@"Now have %lu devices", self.devices.count);
    _lua_stackguard_exit(skin.L);
    return deck;
}
*/

- (void)deviceDidDisconnect:(IOHIDDeviceRef)device {
    /*
    for (HSGamepadDevice *deckDevice in self.devices) {
        if (deckDevice.device == device) {
            [deckDevice invalidate];
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
                [skin logWarn:@"hs.gamepad detected a device disconnecting, but no callback has been set. See hs.gamepad.discoveryCallback()"];
            } else {
                [skin pushLuaRef:gamepadRefTable ref:self.discoveryCallbackRef];
                lua_pushboolean(skin.L, 0);
                [skin pushNSObject:deckDevice];
                [skin protectedCallAndError:@"hs.gamepad:deviceDidDisconnect" nargs:2 nresults:0];
            }

            [self.devices removeObject:deckDevice];
            _lua_stackguard_exit(skin.L);
            return;
        }
    }
    NSLog(@"ERROR: A Gamepad was disconnected that we didn't know about");
    return;
     */
}

@end
