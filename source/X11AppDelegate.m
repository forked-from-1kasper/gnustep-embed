#import <X11Application.h>

#include <X11/XKBlib.h>
#include <X11/keysym.h>

static Atom _X11Atom[ATOM_TOTAL]; const Atom * const X11Atom = _X11Atom;

const char * X11AtomName(enum Atom index) {
    switch (index) {
        case WMName:         return "WM_NAME";
        case WMProtocols:    return "WM_PROTOCOLS";
        case WMDeleteWindow: return "WM_DELETE_WINDOW";
        case NetWMPid:       return "_NET_WM_PID";
    }

    return NULL;
}

static KeySym keysymFromDefaults(NSUserDefaults * defaults, NSString * keyDefaultKey, KeySym fallback) {
    NSString * keyDefaultName = [defaults stringForKey:keyDefaultKey];
    return keyDefaultName == nil ? fallback : XStringToKeysym([keyDefaultName cString]);
}

static int X11ErrorHandler(Display * display, XErrorEvent * err) {
    return [(X11AppDelegate *) [NSApp delegate] catchError:err
                                                   display:display];
}

@implementation X11AppDelegate
- (void) setIcon:(NSString *) icon
{
    ASSIGN(_icon, icon);
}

- (void) setTitle:(NSString *) title
{
    ASSIGN(_title, title);
}

- (void) setFilepath:(NSString *) filepath
{
    ASSIGN(_filepath, filepath);
}

- (void) setArguments:(NSString *) arguments
{
    ASSIGN(_arguments, arguments);
}

- (void) applicationWillTerminate:(NSNotification *) notification
{
    [[notification object] forcefullyQuit];
}

- (void) setupRunLoopForMode:(NSRunLoopMode) mode
{
    Display * display = X11Display();
    NSRunLoop * loop = [NSRunLoop currentRunLoop];
    int xEventQueueFd = XConnectionNumber(display);

    [loop addEvent:(void *) (gsaddr) xEventQueueFd
              type:ET_RDESC
           watcher:(id) self
           forMode:mode];
}

+ (id) alloc
{
    X11AppDelegate * object = [super alloc];
    Display * display = X11Display();

    object->windowDelegate   = [X11WindowDelegate alloc];
    object->commmandKeysym   = keysymFromDefaults([NSUserDefaults standardUserDefaults], @"GSFirstCommandKey", XK_Alt_L);
    object->commandKeycode   = XKeysymToKeycode(display, object->commmandKeysym);
    object->commandModifiers = XkbKeysymToModifiers(display, object->commmandKeysym);

    for (enum Atom index = ATOM_FIRST; index <= ATOM_LAST; index++)
        _X11Atom[index] = XInternAtom(display, X11AtomName(index), True);

    return object;
}

- (void) dealloc
{
    RELEASE(_icon);
    RELEASE(_title);
    RELEASE(_filepath);
    RELEASE(_arguments);
    RELEASE(windowDelegate);

    [super dealloc];
}

- (void) applicationWillFinishLaunching:(NSNotification *) notification
{
    _GSErrorHandler = XSetErrorHandler(X11ErrorHandler);

    [self setupRunLoopForMode:NSDefaultRunLoopMode];
    [self setupRunLoopForMode:NSConnectionReplyMode];
    [self setupRunLoopForMode:NSModalPanelRunLoopMode];
    [self setupRunLoopForMode:NSEventTrackingRunLoopMode];

    if (_icon != nil) [NSApp setApplicationIconImage:[[NSImage alloc] initWithContentsOfFile:_icon]];

    [NSApp setMainMenu:globalMenu(_title == nil ? @"" : _title)];
}

- (void) createWindow:(id) sender
{
    NSUInteger windowStyle = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSRect windowRect = NSMakeRect(100, 100, 900, 600);

    X11Window * window = [[X11Window alloc] initWithContentRect:windowRect
                                                      styleMask:windowStyle
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];

    /* [[NSWindowController alloc] initWithWindow:window]; */

    [window setFilepath:_filepath withArguments:_arguments];
    [window setDelegate:windowDelegate];
    [window orderFrontRegardless];
    [window makeKeyWindow];
    [window newTab];
}

- (void) receivedEvent:(void *) data
                  type:(RunLoopEventType) type
                 extra:(void *) extra
               forMode:(NSRunLoopMode) mode
{
    XEvent event;

    GSDisplayServer<X11> * xserver = GSCurrentServer();
    Display * display = X11Display();

    while (XPending(display) > 0) {
        XNextEvent(display, &event);

        switch (event.type) {
            case MapNotify: {
                const XMapEvent * req = &event.xmap;

                if (req->event != req->window && [[X11App() lookupObserver:req->event] xMapEvent:req->window])
                    goto skip;

                break;
            }

            case PropertyNotify: {
                const XPropertyEvent * req = &event.xproperty;

                if (req->atom == X11Atom[WMName])
                    if ([[X11App() lookupManaged:req->window] xPropertyEvent])
                        goto skip;

                break;
            }

            case DestroyNotify: {
                const XDestroyWindowEvent * req = &event.xdestroywindow;

                if ([[X11App() lookupManaged:req->window] xDestroyEvent:req->window])
                    goto skip;

                break;
            }

            case ButtonPress: {
                if (mode == NSDefaultRunLoopMode) {
                    const XButtonEvent * req = &event.xbutton;

                    if ([[X11App() lookupManaged:req->window] xButtonEvent]) {
                        XSendEvent(display, req->window, False, ButtonPressMask, &event);
                        goto skip;
                    }
                }

                break;
            }

            case KeyRelease: case KeyPress: {
                const XKeyEvent * req = &event.xkey;

                if (mode == NSDefaultRunLoopMode) {
                    BOOL grabbed = (req->state & commandModifiers) || (req->keycode == commandKeycode);

                    if ([X11App() lookupManaged:req->window] != nil) {
                        if (grabbed) [X11Application xForwardKeyToRoot:&event]; // replay WM hotkeys if needed
                        else {
                            XSendEvent(display, req->window, False, KeyPressMask | KeyReleaseMask, &event);
                            goto skip;
                        }
                    }

                    if (!grabbed && [[X11App() lookupObserver:req->window] xForwardKey:&event])
                        goto skip;
                }

                break;
            }
        }

        [xserver processEvent:&event]; skip:
    }
}

- (int) catchError:(XErrorEvent *) err
           display:(Display *) display
{
    if (err->error_code == BadWindow) {
        Window winref = err->resourceid;

        /* Something went wrong and we simply detach that window.
           X11 is totally asynchronous so that’s OK.

           “afterDelay:” is used here to ensure that the following
           code will be executed outside of error handler. */
        Invocation * invoke = [Invocation new:@selector(unmanage:)
                                   withObject:(id) winref];
        [invoke performSelector:@selector(fire:)
                     withObject:[X11App() lookupManaged:winref]
                     afterDelay:0.0];
    }

    return _GSErrorHandler(display, err);
}

@end
