#import <X11Application.h>

@implementation X11Application
+ (id) alloc
{
    X11Application * object = [super alloc];

    object->observer = NSCreateMapTable(NSIntMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);
    object->managed  = NSCreateMapTable(NSIntMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);

    return object;
}

+ (void) xForwardKeyToRoot:(XEvent *) event
{
    Window root               = event->xkey.root;
    XEvent synthEvent         = *event;
    synthEvent.xkey.window    = root;
    synthEvent.xkey.subwindow = None;
    XSendEvent(X11Display(), root, False, KeyPressMask | KeyReleaseMask, &synthEvent);
}

+ (Invocation *) invokeOnKeyWindow:(SEL) sel
{
    return [[Invocation new:@selector(performSelectorOnKeyWindow:)
                 withTarget:NSApp
                 withObject:(id) sel] setFireproof];
}

+ (Invocation *) invokeOnKeyWindow:(SEL) sel
                        withObject:(id) obj
{
    return [[Invocation new:@selector(performSelectorOnKeyWindow:withObject:)
                 withTarget:NSApp
                 withObject:(id) sel
                 withObject:obj] setFireproof];
}

- (id) performSelectorOnKeyWindow:(SEL) sel
{
    NSWindow * window = [self keyWindow];
    return [window respondsToSelector:sel] ? [window performSelector:sel]
                                           : nil;
}

- (id) performSelectorOnKeyWindow:(SEL) sel
                       withObject:(id) obj1
{
    NSWindow * window = [self keyWindow];
    return [window respondsToSelector:sel] ? [window performSelector:sel
                                                          withObject:obj1]
                                           : nil;
}

- (id) performSelectorOnKeyWindow:(SEL) sel
                       withObject:(id) obj1
                       withObject:(id) obj2
{
    NSWindow * window = [self keyWindow];
    return [window respondsToSelector:sel] ? [window performSelector:sel
                                                          withObject:obj1
                                                          withObject:obj2]
                                           : nil;
}

- (void) addObserver:(X11Window *) window
{
    NSMapInsert(observer, (void *) X11Ref(window), window);
}

- (void) removeObserver:(X11Window *) window
{
    NSMapRemove(observer, (void *) X11Ref(window));
}

- (void) manage:(Window) winref
             by:(X11Window *) window
{
    NSMapInsert(managed, (void *) winref, window);
}

- (void) unmanage:(Window) winref
{
    NSMapRemove(managed, (void *) winref);
}

- (X11Window *) lookupObserver:(Window) winref
{
    return NSMapGet(observer, (void *) winref);
}

- (X11Window *) lookupManaged:(Window) winref
{
    return NSMapGet(managed, (void *) winref);
}

- (void) forcefullyQuit
{
    NSMapEnumerator it = NSEnumerateMapTable(observer);
    Window winref; X11Window * window;

    while (NSNextMapEnumeratorPair(&it, (void *) &winref, (void *) &window))
        [window sendSignalToAllTabs:SIGKILL];

    NSEndMapTableEnumeration(&it);
}
@end

static NSMenuItem * viewMenuItem() {
    NSMenu * menu = [NSMenu new];

    [[menu addItemWithTitle:@"New tab"
                     action:@selector(fire:)
              keyEquivalent:@"t"]
                  setTarget:[X11Application invokeOnKeyWindow:@selector(newTab)]];

    [[menu addItemWithTitle:@"Close tab"
                     action:@selector(fire:)
              keyEquivalent:@"w"]
                  setTarget:[X11Application invokeOnKeyWindow:@selector(closeCurrentTab)]];

    [[menu addItemWithTitle:@"Refresh"
                     action:@selector(fire:)
              keyEquivalent:@"u"]
                  setTarget:[X11Application invokeOnKeyWindow:@selector(refresh)]];

    NSMenuItem * menuItem = [NSMenuItem new];
    [menuItem setTitle:@"View"];
    [menuItem setSubmenu:menu];

    return menuItem;
}

static NSMenuItem * setSignalMenuItem() {
    NSMenu * menu = [NSMenu new];

    [[menu addItemWithTitle:@"SIGINT"
                     action:@selector(fire:)
              keyEquivalent:@""]
                  setTarget:[X11Application invokeOnKeyWindow:@selector(sendSignalToCurrentTab:)
                                                   withObject:(id) SIGINT]];

    [[menu addItemWithTitle:@"SIGKILL"
                     action:@selector(fire:)
              keyEquivalent:@"k"]
                  setTarget:[X11Application invokeOnKeyWindow:@selector(sendSignalToCurrentTab:)
                                                   withObject:(id) SIGKILL]];

    [[menu addItemWithTitle:@"SIGTERM"
                     action:@selector(fire:)
              keyEquivalent:@""]
                  setTarget:[X11Application invokeOnKeyWindow:@selector(sendSignalToCurrentTab:)
                                                   withObject:(id) SIGTERM]];

    NSMenuItem * menuItem = [NSMenuItem new];
    [menuItem setTitle:@"Send signal"];
    [menuItem setSubmenu:menu];

    return menuItem;
}

static NSMenuItem * windowsMenuItem() {
    NSMenu * menu = [NSMenu new];

    [menu addItemWithTitle:@"New"
                    action:@selector(createWindow:)
             keyEquivalent:@"n"];

    [[menu addItemWithTitle:@"Close window"
                     action:@selector(fire:)
              keyEquivalent:@"W"]
                  setTarget:[X11Application invokeOnKeyWindow:@selector(performClose:)]];

    [menu addItem:setSignalMenuItem()];

    [NSApp setWindowsMenu:menu];

    NSMenuItem * menuItem = [NSMenuItem new];
    [menuItem setTitle:@"Windows"];
    [menuItem setSubmenu:menu];

    return menuItem;
}

NSMenu * globalMenu(NSString * title) {
    NSMenu * menu = [NSMenu new];
    [menu setTitle:title];

    [menu addItemWithTitle:@"Memory..."
                    action:@selector(orderFrontSharedMemoryPanel:)
             keyEquivalent:@""];

    [menu addItem:windowsMenuItem()];

    [menu addItem:viewMenuItem()];

    [menu addItemWithTitle:@"Hide"
                    action:@selector(hide:)
             keyEquivalent:@"h"];

    [menu addItemWithTitle:@"Quit"
                    action:@selector(terminate:)
             keyEquivalent:@"q"];

    return menu;
}
