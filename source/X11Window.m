#import <X11Window.h>
#import <X11Application.h>

#include <X11/Xatom.h>

@implementation X11WindowDelegate
- (BOOL) windowShouldClose:(X11Window *) window
{
    if (![window isEmpty])
        if (NSRunAlertPanel(@"Close",
                            @"Closing this window will terminate "
                            @"running process(es) inside it.",
                            @"Cancel", @"Close anyway", nil) ==
            NSAlertDefaultReturn)
            return NO;

    // Someone cannot wait so we simply SIGKILL everything.
    [window sendSignalToAllTabs:SIGKILL];

    return YES;
}

- (void) windowWillClose:(NSNotification *) notification
{
    X11Window * window = [notification object];

    [window forEachChildren:@selector(unmanage:) target:window];
    [X11App() removeObserver:window];
}

- (void) windowDidResize:(NSNotification *) notification
{
    X11Window * window = [notification object];
    [window updateRect];
}
@end

@implementation X11Window
+ (void) sendWMDelete:(Window) winref
{
    Display * display = X11Display();

    XEvent event; memset(&event, 0, sizeof(event));
    event.xclient.type         = ClientMessage;
    event.xclient.window       = winref;
    event.xclient.message_type = X11Atom[WMProtocols];
    event.xclient.format       = 32;
    event.xclient.data.l[0]    = X11Atom[WMDeleteWindow];
    event.xclient.data.l[1]    = CurrentTime;
    XSendEvent(display, winref, False, NoEventMask, &event);
}

+ (id) alloc
{
    X11Window * object = [super alloc];

    object->tabView = [NSTabView alloc];
    object->tasks   = [NSMutableArray alloc];

    return object;
}

- (id) initWithContentRect:(NSRect) rect
                 styleMask:(NSUInteger) style
                   backing:(NSBackingStoreType) bufferingType
                     defer:(BOOL) flag
{
    [super initWithContentRect:rect styleMask:style backing:bufferingType defer:flag];

    Display * display = X11Display();

    XSelectInput(display, X11Ref(self), FocusChangeMask |
                                           ExposureMask |
                                     PropertyChangeMask |
                                    StructureNotifyMask |
                                 SubstructureNotifyMask |
                                           KeyPressMask |
                                         KeyReleaseMask |
                                        ButtonPressMask |
                                      ButtonReleaseMask);
    XSync(display, False);

    [tasks init];

    [tabView initWithFrame:NSZeroRect];
    [tabView setDelegate:self];
    [self setContentView:tabView];

    [X11App() addObserver:self];

    [self refresh];

    return self;
}

- (void) setFilepath:(NSString *) filepath
       withArguments:(NSString *) arguments
{
    ASSIGN(_filepath,  filepath);
    ASSIGN(_arguments, arguments);
}

- (void) dealloc
{
    RELEASE(_filepath);
    RELEASE(_arguments);

    RELEASE(tasks);
    RELEASE(tabView);

    [super dealloc];
}

- (void) manage:(Window) winref
{
    Display * display = X11Display();

    NSTabViewItem * tab = [NSTabViewItem alloc];
    [tab initWithIdentifier:[NSNumber numberWithInt:winref]];

    [tabView addTabViewItem:tab];
    [tabView selectTabViewItem:tab];

    [X11App() manage:winref by:self];

    XSelectInput(display, winref, PropertyChangeMask);
    XGrabButton(display, AnyButton, AnyModifier, winref, False, ButtonPressMask, GrabModeAsync, GrabModeAsync, None, None);
    XGrabKey(display, AnyKey, AnyModifier, winref, False, GrabModeAsync, GrabModeAsync);

    [self refresh];
}

- (void) unmanage:(Window) winref
{
    NSInteger index = [tabView indexOfTabViewItemWithIdentifier:[NSNumber numberWithInt:winref]];
    [tabView removeTabViewItem:[tabView tabViewItemAtIndex:index]];

    [X11App() unmanage:winref];

    [self refresh];
    [self closeWhenEmpty];
}

- (BOOL) xMapEvent:(Window) winref
{
    [self manage:winref];
    [self updateRect];
    [self updateTitle];
    return YES;
}

- (BOOL) xPropertyEvent
{
    [self updateTitle];
    return YES;
}

- (BOOL) xDestroyEvent:(Window) winref
{
    [self unmanage:winref];
    return YES;
}

- (BOOL) xButtonEvent
{
    [self makeKeyAndOrderFront:self];
    return YES;
}

- (BOOL) xForwardKey:(XEvent *) event
{
    Window winref = [self currentTabX11Ref];
    if (winref == 0) return NO;

    XEvent synthEvent         = *event;
    synthEvent.xkey.window    = winref;
    synthEvent.xkey.subwindow = None;

    XSendEvent(X11Display(), winref, False, KeyPressMask | KeyReleaseMask, &synthEvent);

    return YES;
}

- (BOOL) isEmpty
{
    return [tabView numberOfTabViewItems] <= 0 && [tasks count] <= 0;
}

- (void) closeWhenEmpty
{
    if ([self isEmpty])
        [self close];
}

- (void) taskDidTerminate:(NSNotification *) notification
{
    [tasks removeObject:[notification object]];
    [self closeWhenEmpty];
}

- (void) newTab
{
    NSTask * task = [NSTask new];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskDidTerminate:)
                                                 name:NSTaskDidTerminateNotification
                                               object:task];

    task.launchPath = _filepath;
    task.arguments  = [[NSString stringWithFormat:_arguments, X11Ref(self)] componentsSeparatedByString:@" "];

    [task launch];

    [tasks addObject:task];
}

- (Window) currentTabX11Ref
{
    NSTabViewItem * tabViewItem = [tabView selectedTabViewItem];
    if (tabViewItem == nil) return 0;

    return (Window) [(NSNumber *) tabViewItem.identifier intValue];
}

- (void) closeCurrentTab
{
    Window winref = [self currentTabX11Ref];

    if (winref == 0) [self close];
    else [X11Window sendWMDelete:winref];
}

- (void) sendSignalToAllTabs:(int) sig
{
    for (NSTask * task in tasks)
        kill([task processIdentifier], sig);
}

- (void) sendSignalToCurrentTab:(int) sig
{
    Window winref = [self currentTabX11Ref]; if (winref == 0) return;

    Atom type; int format; unsigned long nItems; unsigned long bytesAfter; uint8_t * data = NULL;
    if (XGetWindowProperty(X11Display(), winref, X11Atom[NetWMPid], 0, 1, False, XA_CARDINAL,
                           &type, &format, &nItems, &bytesAfter, &data) == Success) {
        int pid = *((int *) data); kill(pid, sig);
    }
}

- (void) forEachChildren:(SEL) sel
                  target:target
{
    Display * display = X11Display();
    Window root, parent; Window * window = NULL;
    unsigned int nchildren = 0;

    XQueryTree(display, X11Ref(self), &root, &parent, &window, &nchildren);

    for (size_t i = 0; i < nchildren; i++)
        [target performSelector:sel
                     withObject:(id) window[i]];

    if (window != NULL) XFree(window);
}

- (void) updateTabLabel:(Window) winref
{
    char * buff = NULL; XFetchName(X11Display(), winref, &buff);

    NSString * title = buff ? [NSString stringWithUTF8String:buff] : @"";
    NSInteger index = [tabView indexOfTabViewItemWithIdentifier:[NSNumber numberWithInt:winref]];
    [[tabView tabViewItemAtIndex:index] setLabel:title]; XFree(buff);
}

- (void) updateTitle
{
    [self forEachChildren:@selector(updateTabLabel:) target:self];
    [self setTitle:[[tabView selectedTabViewItem] label]];

    [tabView setNeedsDisplay:YES];
}

- (void) tabView:(NSTabView *) _tabView didSelectTabViewItem:(NSTabViewItem *) tabViewItem
{
    if ([_tabView numberOfTabViewItems] <= 0) return;

    Window winref = [(NSNumber *) tabViewItem.identifier intValue];
    XRaiseWindow(X11Display(), winref);

    [self setTitle:[tabViewItem label]];
}

- (void) updateChildRect:(Window) winref
{
    Display * display = X11Display();

    NSRect rect = tabView.contentRect;
    XMoveWindow(display, winref, rect.origin.x, rect.origin.y);
    XResizeWindow(display, winref, rect.size.width, rect.size.height);
}

- (void) updateRect
{
    // I don’t think that there is someone who is going to use gazillions of tabs,
    // so preventive resizing of each children shouldn’t be that slow.
    [self forEachChildren:@selector(updateChildRect:) target:self];
}

- (void) refresh
{
    [tabView setTabViewType:[tabView numberOfTabViewItems] <= 1 ? NSNoTabsNoBorder
                                                                : NSTopTabsBezelBorder];

    [self updateTitle]; [self updateRect];
}

- (void) gracefullyQuit
{
    [self forEachChildren:@selector(sendWMDelete:) target:[X11Window class]];
}
@end