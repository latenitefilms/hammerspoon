@import Cocoa;
@import LuaSkin;

#import "HSSpeedEditorManager.h"
#import "HSSpeedEditorDevice.h"
#import "speededitor.h"

#define USERDATA_TAG "hs.speededitor"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static HSSpeedEditorManager *deckManager;
int speedEditorRefTable = LUA_NOREF;

#pragma mark - Lua API
static int speededitor_gc(lua_State *L __unused) {
    [deckManager stopHIDManager];
    [deckManager doGC];
    return 0;
}

/// hs.speededitor.init(fn)
/// Function
/// Initialises the Gamepad driver and sets a discovery callback
///
/// Parameters:
///  * fn - A function that will be called when a Streaming Deck is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.speededitor object, being the device that was connected/disconnected
///
/// Returns:
///  * None
///
/// Notes:
///  * This function must be called before any other parts of this module are used
static int speededitor_init(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    deckManager = [[HSSpeedEditorManager alloc] init];
    deckManager.discoveryCallbackRef = [skin luaRef:speedEditorRefTable atIndex:1];
    [deckManager startHIDManager];

    return 0;
}

/// hs.speededitor.discoveryCallback(fn)
/// Function
/// Sets/clears a callback for reacting to device discovery events
///
/// Parameters:
///  * fn - A function that will be called when a Streaming Deck is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.speededitor object, being the device that was connected/disconnected
///
/// Returns:
///  * None
static int speededitor_discoveryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    deckManager.discoveryCallbackRef = [skin luaUnref:speedEditorRefTable ref:deckManager.discoveryCallbackRef];

    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        deckManager.discoveryCallbackRef = [skin luaRef:speedEditorRefTable atIndex:1];
    }

    return 0;
}

/// hs.speededitor.numDevices()
/// Function
/// Gets the number of Gamepad devices connected
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of Gamepad devices attached to the system
static int speededitor_numDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushinteger(skin.L, deckManager.devices.count);
    return 1;
}

/// hs.speededitor.getDevice(num)
/// Function
/// Gets an hs.speededitor object for the specified device
///
/// Parameters:
///  * num - A number that should be within the bounds of the number of connected devices
///
/// Returns:
///  * An hs.speededitor object
static int speededitor_getDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];

    [skin pushNSObject:deckManager.devices[lua_tointeger(skin.L, 1) - 1]];
    return 1;
}

/// hs.speededitor:buttonCallback(fn)
/// Method
/// Sets/clears the button callback function for a deck
///
/// Parameters:
///  * fn - A function to be called when a button is pressed/released on the stream deck. It should receive three arguments:
///   * The hs.speededitor userdata object
///   * A number containing the button that was pressed/released
///   * A boolean indicating whether the button was pressed (true) or released (false)
///
/// Returns:
///  * The hs.speededitor device
static int speededitor_buttonCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    HSSpeedEditorDevice *device = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"];
    device.buttonCallbackRef = [skin luaUnref:speedEditorRefTable ref:device.buttonCallbackRef];

    if (lua_type(skin.L, 2) == LUA_TFUNCTION) {
        device.buttonCallbackRef = [skin luaRef:speedEditorRefTable atIndex:2];
    }

    lua_pushvalue(skin.L, 1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSSpeedEditorDevice(lua_State *L, id obj) {
    HSSpeedEditorDevice *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSSpeedEditorDevice *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSSpeedEditorDeviceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSpeedEditorDevice *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSSpeedEditorDevice, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int speededitor_object_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSpeedEditorDevice *obj = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"] ;
    NSString *title = [NSString stringWithFormat:@"%@, serial: %@", obj.deckType, obj.serialNumber];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int speededitor_object_eq(lua_State* L) {
    // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
    // so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSSpeedEditorDevice *obj1 = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"] ;
        HSSpeedEditorDevice *obj2 = [skin luaObjectAtIndex:2 toClass:"HSSpeedEditorDevice"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int speededitor_object_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSpeedEditorDevice *theDevice = get_objectFromUserdata(__bridge_transfer HSSpeedEditorDevice, L, 1, USERDATA_TAG) ;
    if (theDevice) {
        theDevice.selfRefCount-- ;
        if (theDevice.selfRefCount == 0) {
            theDevice.buttonCallbackRef = [skin luaUnref:speedEditorRefTable ref:theDevice.buttonCallbackRef] ;
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
    {"buttonCallback", speededitor_buttonCallback},

    {"__tostring", speededitor_object_tostring},
    {"__eq", speededitor_object_eq},
    {"__gc", speededitor_object_gc},
    {NULL, NULL}
};

#pragma mark - Lua Library function definitions
static const luaL_Reg streamdecklib[] = {
    {"init", speededitor_init},
    {"discoveryCallback", speededitor_discoveryCallback},
    {"numDevices", speededitor_numDevices},
    {"getDevice", speededitor_getDevice},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", speededitor_gc},

    {NULL, NULL}
};

#pragma mark - Lua initialiser
int luaopen_hs_speededitor_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    speedEditorRefTable = [skin registerLibrary:streamdecklib metaFunctions:metalib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSSpeedEditorDevice         forClass:"HSSpeedEditorDevice"];
    [skin registerLuaObjectHelper:toHSSpeedEditorDeviceFromLua forClass:"HSSpeedEditorDevice" withTableMapping:USERDATA_TAG];

    return 1;
}

