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

#include <Cocoa/Cocoa.h>

#include "desktop/plotters.h"
#import "desktop/plot_style.h"

#import "cocoa/font.h"
#import "cocoa/plotter.h"
#import "cocoa/bitmap.h"

#define UNIMPL() NSLog( @"Function '%s' unimplemented", __func__ )

static void cocoa_plot_render_path(NSBezierPath *path,const plot_style_t *pstyle);
static void cocoa_plot_path_set_stroke_pattern(NSBezierPath *path,const plot_style_t *pstyle);
static NSRect cocoa_plot_clip_rect;

#define colour_red_component( c )		(((c) >>  0) & 0xFF)
#define colour_green_component( c )		(((c) >>  8) & 0xFF)
#define colour_blue_component( c )		(((c) >> 16) & 0xFF)
#define colour_alpha_component( c )		(((c) >> 24) & 0xFF)
#define colour_from_rgba( r, g, b, a)	((((colour)(r)) <<  0) | \
										 (((colour)(g)) <<  8) | \
										 (((colour)(b)) << 16) | \
										 (((colour)(a)) << 24))
#define colour_from_rgb( r, g, b ) colour_from_rgba( (r), (g), (b), 0xFF )

NSColor *cocoa_convert_colour( colour clr )
{
	return [NSColor colorWithDeviceRed: (float)colour_red_component( clr ) / 0xFF 
								 green: (float)colour_green_component( clr ) / 0xFF 
								  blue: (float)colour_blue_component( clr ) / 0xFF 
								 alpha: 1.0];
}

static void cocoa_plot_path_set_stroke_pattern(NSBezierPath *path,const plot_style_t *pstyle) 
{
	static const CGFloat dashed_pattern[2] = { 5.0, 2.0 };
	static const CGFloat dotted_pattern[2] = { 2.0, 2.0 };
	
	switch (pstyle->stroke_type) {
		case PLOT_OP_TYPE_DASH: 
			[path setLineDash: dashed_pattern count: 2 phase: 0];
			break;
			
		case PLOT_OP_TYPE_DOT: 
			[path setLineDash: dotted_pattern count: 2 phase: 0];
			break;
			
		default:
			// ignore
			break;
	}

	[path setLineWidth: pstyle->stroke_width];
}

static bool plot_line(int x0, int y0, int x1, int y1, const plot_style_t *pstyle)
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint: NSMakePoint( x0, y0 )];
	[path lineToPoint: NSMakePoint( x1, y1 )];
	
	cocoa_plot_render_path( path, pstyle );
	
	return true;
}

static bool plot_rectangle(int x0, int y0, int x1, int y1, const plot_style_t *pstyle)
{
	NSBezierPath *path = [NSBezierPath bezierPathWithRect: NSMakeRect( x0, y0, x1-x0, y1-y0 )];
	
	cocoa_plot_render_path( path, pstyle );
	
	return true;
}

static bool plot_text(int x, int y, const char *text, size_t length,
			 const plot_font_style_t *fstyle)
{
	[NSGraphicsContext saveGraphicsState];
	[NSBezierPath clipRect: cocoa_plot_clip_rect];
	
	cocoa_draw_string( x, y, text, length, fstyle );
	
	[NSGraphicsContext restoreGraphicsState];
	
	return true;
}


static bool plot_clip(int x0, int y0, int x1, int y1)
{
	cocoa_plot_clip_rect = NSMakeRect( x0, y0, abs(x1-x0), abs(y1-y0) );
	return true;
}

void cocoa_plot_render_path(NSBezierPath *path,const plot_style_t *pstyle) 
{
	[NSGraphicsContext saveGraphicsState];
	[NSBezierPath clipRect: cocoa_plot_clip_rect];
	
	if (pstyle->fill_type != PLOT_OP_TYPE_NONE) {
		[cocoa_convert_colour( pstyle->fill_colour ) setFill];
		[path fill];
	}
	
	if (pstyle->stroke_type != PLOT_OP_TYPE_NONE) {
		cocoa_plot_path_set_stroke_pattern(path,pstyle);
		
		[cocoa_convert_colour( pstyle->stroke_colour ) set];
		
		[path stroke];
	}
	
	[NSGraphicsContext restoreGraphicsState];
}

static bool plot_arc(int x, int y, int radius, int angle1, int angle2, const plot_style_t *pstyle)
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path appendBezierPathWithArcWithCenter: NSMakePoint( x, y ) radius: radius 
								 startAngle: angle1 endAngle: angle2 
								  clockwise: NO];
	
	cocoa_plot_render_path( path, pstyle);
	
	return true;
}

static bool plot_disc(int x, int y, int radius, const plot_style_t *pstyle)
{
	NSBezierPath *path  = [NSBezierPath bezierPathWithOvalInRect: 
						   NSMakeRect( x - radius, y-radius, 2*radius, 2*radius )];
	
	cocoa_plot_render_path( path, pstyle );
	
	return true;
}

static bool plot_polygon(const int *p, unsigned int n, const plot_style_t *pstyle)
{
	if (n <= 1) return true;
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint: NSMakePoint( p[0], p[1] )];
	for (int i = 1; i < n; i++) {
		[path lineToPoint: NSMakePoint( p[2*i], p[2*i+1] )];
	}
	[path closePath];
	
	cocoa_plot_render_path( path, pstyle );
	
	return true;
}

/* complex path (for SVG) */
static bool plot_path(const float *p, unsigned int n, colour fill, float width,
			 colour c, const float transform[6])
{
	UNIMPL();
	return true;
}

/* Image */
static bool plot_bitmap(int x, int y, int width, int height,
			   struct bitmap *bitmap, colour bg,
			   bitmap_flags_t flags)
{
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState( context );

	CGContextClipToRect( context, NSRectToCGRect( cocoa_plot_clip_rect ) );
	
	const bool tileX = flags & BITMAPF_REPEAT_X;
	const bool tileY = flags & BITMAPF_REPEAT_Y;

	CGImageRef img = cocoa_get_cgimage( bitmap );

	CGRect rect = CGRectMake( x, y, width, height );
	if (tileX || tileY) {
		CGContextDrawTiledImage( context, rect, img );
	} else {
		CGContextDrawImage( context, rect, img );
	}
	
	CGContextRestoreGState( context );
	
	return true;
}

struct plotter_table plot = {
	.clip = plot_clip,
	.arc = plot_arc,
	.disc = plot_disc,
	.rectangle = plot_rectangle,
	.line = plot_line,
	.polygon = plot_polygon,
	
	.path = plot_path,
	
	.bitmap = plot_bitmap,
	
	.text = plot_text,

	.option_knockout = true
};