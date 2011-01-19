/*
 * Copyright 2011 Sven Weidauer <sven.weidauer@gmail.com>
 *
 * This file is part of NetSurf, http://www.netsurf-browser.org/
 *
 * NetSurf is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License.
 *
 * NetSurf is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Cocoa/Cocoa.h>

#import "BrowserWindow.h"
#import "BrowserView.h"

#import "desktop/gui.h"
#import "desktop/netsurf.h"
#import "desktop/browser.h"
#import "desktop/options.h"
#import "desktop/textinput.h"
#import "desktop/selection.h"
#import "utils/utils.h"

char *default_stylesheet_url;
char *adblock_stylesheet_url;
char *quirks_stylesheet_url;

#define UNIMPL() NSLog( @"Function '%s' unimplemented", __func__ )

void gui_multitask(void)
{
	// nothing to do
}

static NSAutoreleasePool *gui_pool = nil;
void gui_poll(bool active)
{
	[gui_pool release];
	gui_pool = [[NSAutoreleasePool alloc] init];
	
	NSEvent *event = [NSApp nextEventMatchingMask: NSAnyEventMask untilDate: active ? nil : [NSDate distantFuture]
										   inMode: NSDefaultRunLoopMode dequeue: YES];
	
	if (nil != event) [NSApp sendEvent: event];
	
	[NSApp updateWindows];
}

void gui_quit(void)
{
	// nothing to do
}

struct browser_window;

struct gui_window *gui_create_browser_window(struct browser_window *bw,
											 struct browser_window *clone, bool new_tab)
{
	if (clone != NULL) bw->scale = clone->scale;
	else bw->scale = (float) option_scale / 100;
	
	return (struct gui_window *)[[BrowserWindow alloc] initWithBrowser: bw];
}

struct browser_window *gui_window_get_browser_window(struct gui_window *g)
{
	return [(BrowserWindow *)g browser];
}

void gui_window_destroy(struct gui_window *g)
{
	[(BrowserWindow *)g release];
}

void gui_window_set_title(struct gui_window *g, const char *title)
{
	[[(BrowserWindow *)g window] setTitle: [NSString stringWithUTF8String: title]];
}

void gui_window_redraw(struct gui_window *g, int x0, int y0, int x1, int y1)
{
	const NSRect rect = NSMakeRect( x0, y0, x1 - x0, y1 - y0 );
	[[(BrowserWindow *)g view] setNeedsDisplayInRect: rect];
}

void gui_window_redraw_window(struct gui_window *g)
{
	[[(BrowserWindow *)g view] setNeedsDisplay: YES];
}

void gui_window_update_box(struct gui_window *g,
						   const union content_msg_data *data)
{
	const CGFloat scale = [(BrowserWindow *)g browser]->scale;
	const NSRect rect = NSMakeRect( data->redraw.object_x * scale,  
								    data->redraw.object_y * scale, 
								    data->redraw.object_width * scale, 
								    data->redraw.object_height * scale );
	[[(BrowserWindow *)g view] setNeedsDisplayInRect: rect];
}

bool gui_window_get_scroll(struct gui_window *g, int *sx, int *sy)
{
	NSCParameterAssert( g != NULL && sx != NULL && sy != NULL );
	
	NSRect visible = [[(BrowserWindow *)g view] visibleRect];
	*sx = NSMinX( visible );
	*sy = NSMinY( visible );
	return true;
}

void gui_window_set_scroll(struct gui_window *g, int sx, int sy)
{
	[[(BrowserWindow *)g view] scrollPoint: NSMakePoint( sx, sy )];
}

void gui_window_scroll_visible(struct gui_window *g, int x0, int y0,
							   int x1, int y1)
{
	gui_window_set_scroll( g, x0, y0 );
}

void gui_window_position_frame(struct gui_window *g, int x0, int y0,
							   int x1, int y1)
{
	UNIMPL();
}

void gui_window_get_dimensions(struct gui_window *g, int *width, int *height,
							   bool scaled)
{
	NSCParameterAssert( width != NULL && height != NULL );
	
	NSRect frame = [[(BrowserWindow *)g view] frame];
	if (scaled) {
		const CGFloat scale = [(BrowserWindow *)g browser]->scale;
		frame.size.width /= scale;
		frame.size.height /= scale;
	}
	*width = NSWidth( frame );
	*height = NSHeight( frame );
}

void gui_window_update_extent(struct gui_window *g)
{
	BrowserWindow * const window = (BrowserWindow *)g;
	struct browser_window *browser = [window browser];
	int width = content_get_width( browser->current_content ) * browser->scale;
	int height = content_get_height( browser->current_content ) * browser->scale;

	[[window view] setFrameSize: NSMakeSize( width, height )];
}

void gui_window_set_status(struct gui_window *g, const char *text)
{
	[[(BrowserWindow *)g view] setStatus: [NSString stringWithUTF8String: text]];
}

void gui_window_set_pointer(struct gui_window *g, gui_pointer_shape shape)
{
	switch (shape) {
		case GUI_POINTER_DEFAULT:
		case GUI_POINTER_WAIT:
		case GUI_POINTER_PROGRESS:
			[[NSCursor arrowCursor] set];
			break;
			
		case GUI_POINTER_CROSS:
			[[NSCursor crosshairCursor] set];
			break;
			
		case GUI_POINTER_POINT:
			[[NSCursor pointingHandCursor] set];
			break;
			
		case GUI_POINTER_CARET:
			[[NSCursor IBeamCursor] set];
			break;

		default:
			NSLog( @"Other cursor %d requested", shape );
			[[NSCursor arrowCursor] set];
			break;
	}
}

void gui_window_hide_pointer(struct gui_window *g)
{
}

void gui_window_set_url(struct gui_window *g, const char *url)
{
	[(BrowserWindow *)g setUrl: [NSString stringWithUTF8String: url]];
}

void gui_window_start_throbber(struct gui_window *g)
{
	[[(BrowserWindow *)g view] setSpinning: YES];
}

void gui_window_stop_throbber(struct gui_window *g)
{
	[[(BrowserWindow *)g view] setSpinning: NO];
}

void gui_window_set_icon(struct gui_window *g, hlcache_handle *icon)
{
	// ignore
}

void gui_window_set_search_ico(hlcache_handle *ico)
{
	UNIMPL();
}

void gui_window_place_caret(struct gui_window *g, int x, int y, int height)
{
	[[(BrowserWindow *)g view] addCaretAt: NSMakePoint( x, y ) height: height];
}

void gui_window_remove_caret(struct gui_window *g)
{
	[[(BrowserWindow *)g view] removeCaret];
}

void gui_window_new_content(struct gui_window *g)
{
}

bool gui_window_scroll_start(struct gui_window *g)
{
	return true;
}

bool gui_window_box_scroll_start(struct gui_window *g,
								 int x0, int y0, int x1, int y1)
{
	return true;
}

bool gui_window_frame_resize_start(struct gui_window *g)
{
	UNIMPL();
	return false;
}

void gui_window_save_link(struct gui_window *g, const char *url, 
						  const char *title)
{
	UNIMPL();
}

void gui_window_set_scale(struct gui_window *g, float scale)
{
	gui_window_redraw_window( g );
}

void gui_drag_save_object(gui_save_type type, hlcache_handle *c,
						  struct gui_window *g)
{
}

void gui_drag_save_selection(struct selection *s, struct gui_window *g)
{
}


void gui_create_form_select_menu(struct browser_window *bw,
								 struct form_control *control)
{
	UNIMPL();
}


void gui_launch_url(const char *url)
{
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: [NSString stringWithUTF8String: url]]];
}

struct ssl_cert_info;

void gui_cert_verify(const char *url, const struct ssl_cert_info *certs, 
					 unsigned long num, nserror (*cb)(bool proceed, void *pw),
					 void *cbpw)
{
	cb( false, cbpw );
}


void gui_401login_open(const char *url, const char *realm,
					   nserror (*cb)(bool proceed, void *pw), void *cbpw)
{
	cb( false, cbpw );
}

static char *gui_get_resource_url( NSString *name, NSString *type )
{
	NSString *path = [[NSBundle mainBundle] pathForResource: name ofType: type];
	return strdup( [[[NSURL fileURLWithPath: path] absoluteString] UTF8String] );
}

static NSString *cocoa_get_preferences_path()
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains( NSApplicationSupportDirectory, NSUserDomainMask, YES );
	NSCAssert( [paths count] >= 1, @"Where is the application support directory?" );
	
	NSString *netsurfPath = [[paths objectAtIndex: 0] stringByAppendingPathComponent: @"NetSurf"];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory = NO;
	BOOL exists = [fm fileExistsAtPath: netsurfPath isDirectory: &isDirectory];
	
	if (!exists) {
		exists = [fm createDirectoryAtPath: netsurfPath attributes: nil];
		isDirectory = YES;
	}
	if (!(exists && isDirectory)) {
		die( "Cannot create netsurf preferences directory" );
	}
	
	return netsurfPath;
}

static const char *cocoa_get_options_file()
{
	NSString *prefPath = [cocoa_get_preferences_path() stringByAppendingPathComponent: @"options"];
	return [prefPath UTF8String];
}

int main( int argc, char **argv )
{
	gui_pool = [[NSAutoreleasePool alloc] init];
	
	const char * const messages = [[[NSBundle mainBundle] pathForResource: @"messages" ofType: nil] UTF8String];
	const char * const options = cocoa_get_options_file();
	default_stylesheet_url = gui_get_resource_url( @"default", @"css" );
	quirks_stylesheet_url = gui_get_resource_url( @"quirks", @"css" );
	adblock_stylesheet_url = gui_get_resource_url( @"adblock", @"css" );
	
	/* initialise netsurf */
	netsurf_init(&argc, &argv, options, messages);

	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	Class principalClass =  NSClassFromString([infoDictionary objectForKey:@"NSPrincipalClass"]);
	NSCAssert([principalClass respondsToSelector:@selector(sharedApplication)], @"Principal class must implement sharedApplication.");
	[principalClass sharedApplication];
	
	NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
	NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
	[mainNib instantiateNibWithOwner:NSApp topLevelObjects:nil];
	[mainNib release];
	
    [NSApp performSelectorOnMainThread:@selector(run) withObject:nil waitUntilDone:YES];
	
	netsurf_exit();
	
	return 0;
}
