@import Cocoa;
@import LuaSkin;

#import "HSGamepadManager.h"
#import "HSGamepadDevice.h"
#import "gamepad.h"

#define USERDATA_TAG "hs.gamepad"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static HSGamepadManager *deckManager;
int gamepadRefTable = LUA_NOREF;

#pragma mark - Lua API
static int gamepad_gc(lua_State *L __unused) {
    [deckManager stopHIDManager];
    [deckManager doGC];
    return 0;
}

/// hs.gamepad.init(fn)
/// Function
/// Initialises the Gamepad driver and sets a discovery callback
///
/// Parameters:
///  * fn - A function that will be called when a Streaming Deck is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.gamepad object, being the device that was connected/disconnected
///
/// Returns:
///  * None
///
/// Notes:
///  * This function must be called before any other parts of this module are used
static int gamepad_init(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    deckManager = [[HSGamepadManager alloc] init];
    deckManager.discoveryCallbackRef = [skin luaRef:gamepadRefTable atIndex:1];
    [deckManager startHIDManager];

    return 0;
}

/// hs.gamepad.discoveryCallback(fn)
/// Function
/// Sets/clears a callback for reacting to device discovery events
///
/// Parameters:
///  * fn - A function that will be called when a Streaming Deck is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.gamepad object, being the device that was connected/disconnected
///
/// Returns:
///  * None
static int gamepad_discoveryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    deckManager.discoveryCallbackRef = [skin luaUnref:gamepadRefTable ref:deckManager.discoveryCallbackRef];

    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        deckManager.discoveryCallbackRef = [skin luaRef:gamepadRefTable atIndex:1];
    }

    return 0;
}

/// hs.gamepad.numDevices()
/// Function
/// Gets the number of Gamepad devices connected
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of Gamepad devices attached to the system
static int gamepad_numDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushinteger(skin.L, deckManager.devices.count);
    return 1;
}

/// hs.gamepad.getDevice(num)
/// Function
/// Gets an hs.gamepad object for the specified device
///
/// Parameters:
///  * num - A number that should be within the bounds of the number of connected devices
///
/// Returns:
///  * An hs.gamepad object
static int gamepad_getDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];

    [skin pushNSObject:deckManager.devices[lua_tointeger(skin.L, 1) - 1]];
    return 1;
}

/// hs.gamepad:buttonCallback(fn)
/// Method
/// Sets/clears the button callback function for a deck
///
/// Parameters:
///  * fn - A function to be called when a button is pressed/released on the stream deck. It should receive three arguments:
///   * The hs.gamepad userdata object
///   * A number containing the button that was pressed/released
///   * A boolean indicating whether the button was pressed (true) or released (false)
///
/// Returns:
///  * The hs.gamepad device
static int gamepad_buttonCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    HSGamepadDevice *device = [skin luaObjectAtIndex:1 toClass:"HSGamepadDevice"];
    device.buttonCallbackRef = [skin luaUnref:gamepadRefTable ref:device.buttonCallbackRef];

    if (lua_type(skin.L, 2) == LUA_TFUNCTION) {
        device.buttonCallbackRef = [skin luaRef:gamepadRefTable atIndex:2];
    }

    lua_pushvalue(skin.L, 1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSGamepadDevice(lua_State *L, id obj) {
    HSGamepadDevice *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSGamepadDevice *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSGamepadDeviceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSGamepadDevice *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSGamepadDevice, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int gamepad_object_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSGamepadDevice *obj = [skin luaObjectAtIndex:1 toClass:"HSGamepadDevice"] ;
    NSString *title = [NSString stringWithFormat:@"%@, serial: %@", obj.deckType, obj.serialNumber];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int gamepad_object_eq(lua_State* L) {
    // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
    // so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSGamepadDevice *obj1 = [skin luaObjectAtIndex:1 toClass:"HSGamepadDevice"] ;
        HSGamepadDevice *obj2 = [skin luaObjectAtIndex:2 toClass:"HSGamepadDevice"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int gamepad_object_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSGamepadDevice *theDevice = get_objectFromUserdata(__bridge_transfer HSGamepadDevice, L, 1, USERDATA_TAG) ;
    if (theDevice) {
        theDevice.selfRefCount-- ;
        if (theDevice.selfRefCount == 0) {
            theDevice.buttonCallbackRef = [skin luaUnref:gamepadRefTable ref:theDevice.buttonCallbackRef] ;
            theDevice = nil ;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

#pragma mark - Lua object function definitions
static const luaL_Reg userdata_metaLib[] = {
    {"buttonCallback", gamepad_buttonCallback},

    {"__tostring", gamepad_object_tostring},
    {"__eq", gamepad_object_eq},
    {"__gc", gamepad_object_gc},
    {NULL, NULL}
};

#pragma mark - Lua Library function definitions
static const luaL_Reg streamdecklib[] = {
    {"init", gamepad_init},
    {"discoveryCallback", gamepad_discoveryCallback},
    {"numDevices", gamepad_numDevices},
    {"getDevice", gamepad_getDevice},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", gamepad_gc},

    {NULL, NULL}
};

#pragma mark - Lua initialiser
int luaopen_hs_gamepad_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    gamepadRefTable = [skin registerLibrary:streamdecklib metaFunctions:metalib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSGamepadDevice         forClass:"HSGamepadDevice"];
    [skin registerLuaObjectHelper:toHSGamepadDeviceFromLua forClass:"HSGamepadDevice" withTableMapping:USERDATA_TAG];

    return 1;
}

