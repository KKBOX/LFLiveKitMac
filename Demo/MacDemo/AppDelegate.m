#import "AppDelegate.h"

@interface AppDelegate ()
@property NSWindowController *controller;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
	self.controller = [storyBoard instantiateControllerWithIdentifier:@"WindowController"];
	self.controller.window.excludedFromWindowsMenu = YES;
	[self.controller showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

- (IBAction)viewMainWindow:(id)sender
{
	[self.controller showWindow:self];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(viewMainWindow:)) {
		if (self.controller.window.miniaturized) {
			menuItem.state = NSMixedState;
		}
		else if (!self.controller.window.visible) {
			menuItem.state = NSOffState;
		}
		else {
			menuItem.state = NSOnState;
		}

	}
	return YES;
}

@end
