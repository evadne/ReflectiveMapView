//
//  RMViewController.m
//  ReflctiveMapView
//
//  Created by Evadne Wu on 7/6/12.
//  Copyright (c) 2012 Iridia Productions. All rights reserved.
//

#import "RMViewController.h"
#import "LoggerClient.h"

#define NSLog LogMessageCompat

@interface RMViewController ()

@end

@implementation RMViewController
@synthesize mapView = _mapView;

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
	
}

- (void) mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {

	UIImage * (^imageFromEAGLView)(UIView *) = ^ (UIView *view) {
	
		NSUInteger width = (NSUInteger)view.bounds.size.width;
		NSUInteger height = (NSUInteger)view.bounds.size.height;
	
		NSInteger dataLength = width * height * 4;

		// allocate array and read pixels into it.
		GLubyte *reverseBuffer = (GLubyte *) malloc(dataLength);
		glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, reverseBuffer);

		// gl renders "upside down" so swap top to bottom into new array.
		// there's gotta be a better way, but this works.
		GLubyte *buffer2 = (GLubyte *) malloc(dataLength);
		
		for(int y = 0; y < height; y++)
			for(int x = 0; x < width * 4; x++)
				buffer2[(height - 1 - y) * width * 4 + x] = reverseBuffer[y * 4 * width + x];

		// make data provider with data.
		CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, dataLength, NULL);

		// prep the ingredients
		int bitsPerComponent = 8;
		int bitsPerPixel = 32;
		int bytesPerRow = 4 * width;
		CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
		CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
		CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;

		// make the cgimage
		CGImageRef imageRef = CGImageCreate((CGFloat)width, (CGFloat)height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);

		return [UIImage imageWithCGImage:imageRef];
	
	};
	
	UIImage * (^imageFromView)(UIView *) = ^ (UIView *view) {
	
		if ([view.layer isKindOfClass:[CAEAGLLayer class]])
			return imageFromEAGLView(view);
	
		UIGraphicsBeginImageContext(view.bounds.size);
		CGContextRef imageContext = UIGraphicsGetCurrentContext();
		[view.layer renderInContext:imageContext];
		UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		return image;
	
	};
	
	__block void (^walk)(UIView *, void(^)(UIView *)) = ^ (UIView *view, void(^block)(UIView *)) {
	
		for (UIView *subview in view.subviews)
			walk(subview, block);
		
		block(view);
	
	};
	
	void (^LogImage)(UIImage *) = ^ (UIImage *image) {
		
		LogImageData(
			[NSString stringWithFormat:@"%p", image],
			0,
			image.size.width,
			image.size.height,
			UIImagePNGRepresentation(image)
		);
		
	};
	
	UIColor * (^averageColor)(UIImage *) = ^ (UIImage *image) {
	
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		unsigned char rgba[4];
		CGContextRef pixelContext = CGBitmapContextCreate(rgba, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		
		CGContextDrawImage(pixelContext, CGRectMake(0, 0, 1, 1), image.CGImage);
		CGColorSpaceRelease(colorSpace);
		CGContextRelease(pixelContext);
	 
		if (rgba[3] > 0) {
				CGFloat alpha = ((CGFloat)rgba[3])/255.0;
				CGFloat multiplier = alpha/255.0;
					return [UIColor colorWithRed:((CGFloat)rgba[0])*multiplier
																 green:((CGFloat)rgba[1])*multiplier
																	blue:((CGFloat)rgba[2])*multiplier
																 alpha:alpha];
			}
			else {
					return [UIColor colorWithRed:((CGFloat)rgba[0])/255.0
																 green:((CGFloat)rgba[1])/255.0
																	blue:((CGFloat)rgba[2])/255.0
																 alpha:((CGFloat)rgba[3])/255.0];
			}
	
	};
	
	NSMutableSet *colors = [NSMutableSet set];
	
	walk(mapView, ^ (UIView *subview) {
	
		if ([[subview layer] isKindOfClass:[CAEAGLLayer class]])
			[colors addObject:averageColor(imageFromView(subview))];
	
	});
	
	if ([colors count])
		self.navigationController.navigationBar.tintColor = (UIColor *)[colors anyObject];

}

@end
