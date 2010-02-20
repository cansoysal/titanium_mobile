/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiUIScrollView.h"
#import "TiUIScrollViewProxy.h"
#import "TiUtils.h"

@implementation TiUIScrollView

- (void) dealloc
{
	RELEASE_TO_NIL(wrapperView);
	RELEASE_TO_NIL(scrollView);
	[super dealloc];
}

-(UIView *)wrapperView
{
	if (wrapperView == nil)
	{
		CGRect wrapperFrame;
		wrapperFrame.size = [[self scrollView] contentSize];
		wrapperFrame.origin = CGPointZero;
		wrapperView = [[UIView alloc] initWithFrame:wrapperFrame];
		[wrapperView setUserInteractionEnabled:YES];
		[scrollView addSubview:wrapperView];
	}
	return wrapperView;
}

-(UIScrollView *)scrollView
{
	if(scrollView == nil)
	{
		scrollView = [[UIScrollView alloc] initWithFrame:[self bounds]];
		[scrollView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
		[scrollView setBackgroundColor:[UIColor clearColor]];
		[scrollView setShowsHorizontalScrollIndicator:NO];
		[scrollView setShowsVerticalScrollIndicator:NO];
		[scrollView setDelegate:self];
		[self addSubview:scrollView];
		
		// set the initial scale to 1.0 which is the default
		[self.proxy replaceValue:NUMFLOAT(1.0) forKey:@"scale" notification:NO];
	}
	return scrollView;
}

-(void)setNeedsHandleContentSizeIfAutosizing
{
	if (TiDimensionIsAuto(contentWidth) || TiDimensionIsAuto(contentHeight))
	{
		[self setNeedsHandleContentSize];
	}
}

-(void)setNeedsHandleContentSize
{
	if (!needsHandleContentSize)
	{
		needsHandleContentSize = YES;
		[self performSelectorOnMainThread:@selector(handleContentSize) withObject:nil waitUntilDone:NO];
	}
}

-(void)handleContentSize
{
	CGSize newContentSize = [self bounds].size;
	
	NSArray * subViews = [[self wrapperView] subviews];
	
	switch (contentWidth.type)
	{
		case TiDimensionTypePixels:
		{
			newContentSize.width = MAX(newContentSize.width,contentWidth.value);
			break;
		}
		case TiDimensionTypeAuto:
		{
			for (TiUIView * thisChildView in subViews)
			{
				newContentSize.width = MAX(newContentSize.width,[thisChildView minimumParentWidthForWidth:newContentSize.width]);
			}
			break;
		}
	}

	switch (contentHeight.type)
	{
		case TiDimensionTypePixels:
		{
			minimumContentHeight = contentHeight.value;
			break;
		}
		case TiDimensionTypeAuto:
		{
			minimumContentHeight = 0.0;
			for (TiUIView * thisChildView in subViews)
			{
				minimumContentHeight = MAX(minimumContentHeight,[thisChildView minimumParentHeightForWidth:newContentSize.width]);
			}
			break;
		}
		default:
			minimumContentHeight = newContentSize.height;
			break;
	}
	newContentSize.height = MAX(newContentSize.height,minimumContentHeight);

	[scrollView setContentSize:newContentSize];
	CGRect wrapperBounds;
	wrapperBounds.origin = CGPointZero;
	wrapperBounds.size = newContentSize;
	[wrapperView setBounds:wrapperBounds];
	[wrapperView setCenter:CGPointMake(newContentSize.width/2, newContentSize.height/2)];
	for (TiUIView * thisChildView in subViews)
	{
		[thisChildView reposition];
		[[thisChildView proxy] layoutChildren:[thisChildView bounds]];
	}

	needsHandleContentSize = NO;
}

-(void)layoutChild:(TiUIView *)childView
{
	// layout out ourself
	if ([childView superview]!=[self wrapperView])
	{
		[wrapperView addSubview:childView];
		[self setNeedsHandleContentSizeIfAutosizing];
	}
	[childView reposition];
}

-(void)setContentWidth_:(id)value
{
	contentWidth = [TiUtils dimensionValue:value];
	[self setNeedsHandleContentSize];
}

-(void)setContentHeight_:(id)value
{
	contentHeight = [TiUtils dimensionValue:value];
	[self setNeedsHandleContentSize];
}

-(void)setShowHorizontalScrollIndicator_:(id)value
{
	[[self scrollView] setShowsHorizontalScrollIndicator:[TiUtils boolValue:value]];
}

-(void)setShowVerticalScrollIndicator_:(id)value
{
	[[self scrollView] setShowsVerticalScrollIndicator:[TiUtils boolValue:value]];
}

-(void)setScrollIndicatorStyle_:(id)value
{
	[[self scrollView] setIndicatorStyle:[TiUtils intValue:value def:UIScrollViewIndicatorStyleDefault]];
}

-(void)setDisableBounce_:(id)value
{
	[[self scrollView] setBounces:![TiUtils boolValue:value]];
}

-(void)setHorizontalBounce_:(id)value
{
	[[self scrollView] setAlwaysBounceHorizontal:[TiUtils boolValue:value]];
}

-(void)setVerticalBounce_:(id)value
{
	[[self scrollView] setAlwaysBounceVertical:[TiUtils boolValue:value]];
}

-(void)setContentOffset_:(id)value
{
	CGPoint newOffset = [TiUtils pointValue:value];
	BOOL animated = scrollView != nil;
	[[self scrollView] setContentOffset:newOffset animated:animated];
}

-(void)setZoomScale_:(id)args
{
	CGFloat scale = [TiUtils floatValue:args];
	[[self scrollView] setZoomScale:scale];
	if ([self.proxy _hasListeners:@"scale"])
	{
		[self.proxy fireEvent:@"scale" withObject:[NSDictionary dictionaryWithObjectsAndKeys:
											NUMFLOAT(scale),@"scale",
											nil]];
	}
}

-(void)setMaxZoomScale_:(id)args
{
	[[self scrollView] setMaximumZoomScale:[TiUtils floatValue:args]];
}

-(void)setMinZoomScale_:(id)args
{
	[[self scrollView] setMinimumZoomScale:[TiUtils floatValue:args]];
}


#pragma mark scrollView delegate stuff


- (void)scrollViewDidScroll:(UIScrollView *)scrollView_               // any offset changes
{
	[(id<UIScrollViewDelegate>)[self proxy] scrollViewDidScroll:scrollView_];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return [self wrapperView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView_ withView:(UIView *)view atScale:(float)scale 
{
	// scale between minimum and maximum. called after any 'bounce' animations
	[(id<UIScrollViewDelegate>)[self proxy] scrollViewDidEndZooming:scrollView withView:(UIView*)view atScale:scale];
}

/*
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;                              // called on start of dragging (may require some time and or distance to move)
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate; // called on finger up if user dragged. decelerate is true if it will continue moving afterwards

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView;   // called on finger up as we are moving
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;      // called when scroll view grinds to a halt

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView; // called when setContentOffset/scrollRectVisible:animated: finishes. not called if not animating

 - (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView;   // return a yes if you want to scroll to the top. if not defined, assumes YES
- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView;      // called when scrolling animation finished. may be called immediately if already at top
*/



-(void)keyboardDidShowAtHeight:(CGFloat)keyboardTop forView:(TiUIView *)firstResponderView
{
	CGRect scrollVisibleRect;
	scrollVisibleRect = [self convertRect:[self bounds] toView:nil];
	//First, find out how much we have to compensate.

	CGFloat obscuredHeight = scrollVisibleRect.origin.y + scrollVisibleRect.size.height - keyboardTop;	
	//ObscuredHeight is how many vertical pixels the keyboard obscures of the scroll view. Some of this may be acceptable.

	CGFloat unimportantArea = MAX(scrollVisibleRect.size.height - minimumContentHeight,0);
	//It's possible that some of the covered area doesn't matter. If it all matters, unimportant is 0.
		
	CGRect responderRect = [firstResponderView convertRect:[firstResponderView bounds] toView:self];

	if(obscuredHeight > unimportantArea)	//If the covered area is an acceptable loss, then we're fine and don't need to add insets.
	{
		[scrollView setContentInset:UIEdgeInsetsMake(0, 0, obscuredHeight - unimportantArea, 0)];

		//To ensure that the obscuredHeight is compensated for, we treat the responder as larger.		
		responderRect.size.height += obscuredHeight;
	}

	//However, we're not done, because it's possible a scrollview was not covered by the keyboard, but still needs to scroll
	//To the firstResponder.

	[scrollView scrollRectToVisible:responderRect animated:YES];
}

-(void)keyboardDidHide
{
	CGSize scrollContentSize = [scrollView contentSize];
	CGPoint scrollOffset = [scrollView contentOffset];
	
	[scrollView setContentInset:UIEdgeInsetsZero];

	//Reposition the scroll to handle the uncovered area.
	CGRect scrollVisibleRect = [self bounds];
	CGFloat maxYScrollOffset = scrollContentSize.height - scrollVisibleRect.size.height;
	if (maxYScrollOffset < scrollOffset.y)
	{
		scrollOffset.y = maxYScrollOffset;
		[scrollView setContentOffset:scrollOffset animated:YES];
	}
}

@end