//
//  HSSpeedEditorManager.m
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSSpeedEditorManager.h"

#define NSSTR(e) ((NSString *)CFSTR(e))

#pragma mark - IOKit C callbacks

static char *inputBuffer = NULL;

static void speedEditorAction(void *ctx, IOReturn inResult, void *inSender, IOHIDValueRef value) {
    NSLog(@"Speed Editor Talked!");
    IOHIDElementRef element = IOHIDValueGetElement(value);
    NSLog(@"Element: %@", element);
    long elementValue = IOHIDValueGetIntegerValue(value);
    NSLog(@"Element value: %li", elementValue);
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    NSLog(@"connect: %p:%p", context, (void *)device);
    HSSpeedEditorManager *manager = (__bridge HSSpeedEditorManager *)context;
    
    IOHIDDeviceRegisterInputValueCallback((void *)device,
                                          speedEditorAction,
                                          (__bridge void * _Nullable)(manager));
}

static void HIDdisconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    NSLog(@"disconnect: %p", (void *)device);
    HSSpeedEditorManager *manager = (__bridge HSSpeedEditorManager *)context;
    [manager deviceDidDisconnect:device];
    IOHIDDeviceRegisterInputValueCallback(device, NULL, NULL);
}

#pragma mark - Gamepad Manager implementation
@implementation HSSpeedEditorManager

- (id)init {
    self = [super init];
    if (self) {
        self.devices = [[NSMutableArray alloc] initWithCapacity:5];
        self.discoveryCallbackRef = LUA_NOREF;
        inputBuffer = malloc(1024);
        
        // Create a HID device manager
        self.ioHIDManager = CFBridgingRelease(IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone));
        //NSLog(@"Created HID Manager: %p", (void *)self.ioHIDManager);
        
        // Create a Matching Dictionary
        CFMutableDictionaryRef matchDict = CFDictionaryCreateMutable(
                                                          kCFAllocatorDefault,
                                                          2,
                                                           &kCFTypeDictionaryKeyCallBacks,
                                                           &kCFTypeDictionaryValueCallBacks);
        
        // Specify a device manufacturer in the Matching Dictionary
        CFDictionarySetValue(matchDict,
                                                   CFSTR(kIOHIDManufacturerKey),
                                                   CFSTR("Blackmagic Design"));
    
        
        IOHIDManagerSetDeviceMatching((__bridge IOHIDManagerRef)self.ioHIDManager, matchDict);

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
- (HSSpeedEditorDevice*)deviceDidConnect:(IOHIDDeviceRef)device {
    NSNumber *vendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *productID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    
    
    NSLog(@"vendorID: %@", vendorID);
    NSLog(@"productID: %@", productID);
    
    return nil;
    

    if (vendorID.intValue != USB_VID_ELGATO) {
        NSLog(@"deviceDidConnect from unknown vendor: %d", vendorID.intValue);
        return nil;
    }

    HSSpeedEditorDevice *deck = nil;

    switch (productID.intValue) {
        case USB_PID_STREAMDECK_ORIGINAL:
            deck = [[HSSpeedEditorDeviceOriginal alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_MINI:
            deck = [[HSSpeedEditorDeviceMini alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_XL:
            deck = [[HSSpeedEditorDeviceXL alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_ORIGINAL_V2:
            deck = [[HSSpeedEditorDeviceOriginalV2 alloc] initWithDevice:device manager:self];
            break;

        default:
            NSLog(@"deviceDidConnect from unknown device: %d", productID.intValue);
            break;
    }
    if (!deck) {
        NSLog(@"deviceDidConnect: no HSSpeedEditorDevice was created, ignoring");
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
    for (HSSpeedEditorDevice *deckDevice in self.devices) {
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
