#include <X11/Xlib.h>

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface X11Window : NSWindow
{
    NSMutableArray * tasks;
    NSTabView      * tabView;

    NSString * _filepath, * _arguments;
}

+ (void) sendWMDelete:(Window) winref;

- (void) forEachChildren:(SEL) sel
                  target:target;

- (void) manage:(Window) winref;
- (void) unmanage:(Window) winref;

- (void) updateTitle;
- (void) updateRect;
- (void) refresh;

- (void) gracefullyQuit;
- (void) closeWhenEmpty;
- (BOOL) isEmpty;

- (void)   newTab;
- (Window) currentTabX11Ref;
- (void)   closeCurrentTab;
- (void)   sendSignalToCurrentTab:(int) sig;

- (void) sendSignalToAllTabs:(int) sig;

- (BOOL) xMapEvent:(Window) winref;
- (BOOL) xPropertyEvent;
- (BOOL) xDestroyEvent:(Window) winref;
- (BOOL) xButtonEvent;
- (BOOL) xForwardKey:(XEvent *) event;

- (void) setFilepath:(NSString *) filepath
       withArguments:(NSString *) arguments;
@end

@interface X11WindowDelegate : NSObject
@end

static inline Window X11Ref(X11Window * window)
{ return (Window) [window windowRef]; }
