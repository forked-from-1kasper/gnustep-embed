#include <X11/Xlib.h>

#import <GNUstepGUI/GSDisplayServer.h>

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import <Invocation.h>
#import <X11Window.h>

@protocol X11
- (void) processEvent:(XEvent *) event;
@end

@interface X11AppDelegate : NSObject
{
    X11WindowDelegate * windowDelegate;

    KeySym       commmandKeysym;
    KeyCode      commandKeycode;
    unsigned int commandModifiers;

    XErrorHandler _GSErrorHandler;

    NSString * _icon, * _title, * _filepath, * _arguments;
}

- (int) catchError:(XErrorEvent *) err
           display:(Display *) display;

- (void) setIcon:(NSString *) icon;
- (void) setTitle:(NSString *) title;
- (void) setFilepath:(NSString *) filepath;
- (void) setArguments:(NSString *) arguments;
@end

@interface X11Application : NSApplication
{
    NSMapTable * observer, * managed;
}

+ (void) xForwardKeyToRoot:(XEvent *) event;

+ (Invocation *) invokeOnKeyWindow:(SEL) sel;
+ (Invocation *) invokeOnKeyWindow:(SEL) sel
                        withObject:(id) obj;

- (id) performSelectorOnKeyWindow:(SEL) sel;
- (id) performSelectorOnKeyWindow:(SEL) sel
                       withObject:(id) obj1;
- (id) performSelectorOnKeyWindow:(SEL) sel
                       withObject:(id) obj1
                       withObject:(id) obj2;

- (void) addObserver:(X11Window *) window;
- (void) removeObserver:(X11Window *) window;

- (void) manage:(Window) winref
             by:(X11Window *) window;

- (void) unmanage:(Window) winref;

- (X11Window *) lookupObserver:(Window) winref;
- (X11Window *) lookupManaged:(Window) winref;

- (void) forcefullyQuit;
@end

static inline X11Application * X11App()
{ return (X11Application *) NSApp; }

static inline Display * X11Display()
{ return (Display *) [GSCurrentServer() serverDevice]; }

NSMenu * globalMenu(NSString *);

extern const Atom * const X11Atom;

enum Atom {
    WMName,
    WMProtocols,
    WMDeleteWindow,
    NetWMPid,

    ATOM_FIRST = WMName,
    ATOM_LAST  = NetWMPid
};

#define ATOM_TOTAL (ATOM_LAST + 1)
