//
//  RSFindBarViewController.m
//  WabbitEdit
//
//  Created by William Towe on 12/29/11.
//  Copyright (c) 2011 Revolution Software.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "RSFindBarViewController.h"
#import "RSFindOptionsViewController.h"
#import "RSDefines.h"
#import "RSBezelWidgetManager.h"
#import "WCDefines.h"
#import "NSTextView+WCExtensions.h"
#import "WCSourceTextView.h"

@interface RSFindBarViewController ()
@property (readwrite,assign,nonatomic) BOOL wrapAround;
@property (readonly,nonatomic) RSFindOptionsViewController *findOptionsViewController;
@property (readwrite,retain,nonatomic) NSRegularExpression *findRegularExpression;
@property (readwrite,copy,nonatomic) NSString *statusString;
@property (readwrite,assign,nonatomic) RSFindBarViewControllerViewMode viewMode;

- (void)_findAndHighlightNearestRange:(BOOL)highlightNearestRange highlightMatches:(BOOL)highlightMatches;
- (void)_addFindTextAttributes;
- (void)_removeFindTextAttributes;
- (void)_addFindTextAttributesInRange:(NSRange)range;
- (void)_removeFindTextAttributesInRange:(NSRange)range;
- (NSRange)_nextRangeDidWrap:(BOOL *)didWrap includeSelectedRange:(BOOL)includeSelectedRange;
- (NSRange)_previousRangeDidWrap:(BOOL *)didWrap;
@end

@implementation RSFindBarViewController
#pragma mark *** Subclass Overrides ***
- (void)dealloc {
#ifdef DEBUG
	NSLog(@"%@ called in %@",NSStringFromSelector(_cmd),[self className]);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_textStorageDidProcessEditingTimer invalidate];
	_textView = nil;
	[_findString release];
	[_findRegularExpression release];
	[_replaceString release];
	[_statusString release];
	[_findRanges release];
	[_showFindBarAnimation release];
	[_hideFindBarAnimation release];
	[_showReplaceControlsAnimation release];
	[_findOptionsViewController release];
	[super dealloc];
}

- (NSString *)nibName {
	return @"RSFindBarView";
}

- (void)loadView {
	[super loadView];
	
	[(NSSearchFieldCell *)[[self searchField] cell] setPlaceholderString:NSLocalizedString(@"String Searching", @"find bar search field placeholder string")];
	[(NSTextFieldCell *)[[self replaceTextField] cell] setPlaceholderString:NSLocalizedString(@"Replace String", @"find bar replace text field placeholder string")];
}
#pragma mark NSMenuValidation
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if ([menuItem action] == @selector(toggleFindOptions:)) {
		if ([[self findOptionsViewController] areFindOptionsVisible])
			[menuItem setTitle:NSLocalizedString(@"Hide Find Options\u2026", @"hide find options with ellipsis")];
		else
			[menuItem setTitle:NSLocalizedString(@"Show Find Options\u2026", @"show find options with ellipsis")];
	}
	return YES;
}
#pragma mark NSAnimationDelegate
- (void)animationDidEnd:(NSAnimation *)animation {
	if (animation == _showFindBarAnimation) {
		[_showFindBarAnimation release];
		_showFindBarAnimation = nil;
		
		[[[self view] window] makeFirstResponder:[self searchField]];
		
		if ([self areReplaceControlsVisible])
			[[self searchField] setNextKeyView:[self replaceTextField]];
		else
			[[self searchField] setNextKeyView:[self textView]];
		
		if (![[self findString] length]) {
			NSString *pboardString = [[NSPasteboard pasteboardWithName:NSFindPboard] stringForType:NSPasteboardTypeString];
			if ([pboardString length])
				[self setFindString:pboardString];
		}
		
		if ([[self findString] length])
			[self find:nil];
		
		if (_findFlags.runShowReplaceControlsAnimationAfterShowFindBarAnimationCompletes) {
			_findFlags.runShowReplaceControlsAnimationAfterShowFindBarAnimationCompletes = NO;
			
			[self showReplaceControls:nil];
		}
	}
	else if (animation == _hideFindBarAnimation) {
		[_hideFindBarAnimation release];
		_hideFindBarAnimation = nil;
		
		[[self view] removeFromSuperviewWithoutNeedingDisplay];
		
		[self performCleanup];
	}
	else if (animation == _showReplaceControlsAnimation) {
		[_showReplaceControlsAnimation release];
		_showReplaceControlsAnimation = nil;
		
		[[self searchField] setNextKeyView:[self replaceTextField]];
		[[self replaceTextField] setNextKeyView:[self textView]];
	}
	else if (animation == _hideReplaceControlsAnimation) {
		[_hideReplaceControlsAnimation release];
		_hideReplaceControlsAnimation = nil;
		
		[self setViewMode:RSFindBarViewControllerViewModeFind];
		
		[[self searchField] setNextKeyView:[self textView]];
	}
}
#pragma mark NSControlTextEditingDelegate
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
	if (commandSelector == @selector(cancelOperation:)) {
		[self hideFindBar:nil];
		return YES;
	}
	else if (commandSelector == @selector(insertNewline:)) {
		if ([control isKindOfClass:[NSSearchField class]]) {
			if ([_findRanges count])
				[self findNext:nil];
			else if ([[self findString] length])
				[self find:nil];
			return YES;
		}
		else if ([control isKindOfClass:[NSTextField class]]) {
			[self replace:nil];
			return YES;
		}
	}
	return NO;
}
#pragma mark RSFindOptionsViewControllerDelegate
- (void)findOptionsViewControllerDidChangeFindOptions:(RSFindOptionsViewController *)viewController {
	if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual)
		[(NSSearchFieldCell *)[[self searchField] cell] setPlaceholderString:NSLocalizedString(@"String Searching", @"String Searching")];
	else
		[(NSSearchFieldCell *)[[self searchField] cell] setPlaceholderString:NSLocalizedString(@"Regex Searching", @"Regex Searching")];
	
	if ([[self findString] length])
		[self find:nil];
}
#pragma mark *** Public Methods ***
- (id)initWithTextView:(NSTextView *)textView {
	if (!(self = [super initWithNibName:[self nibName] bundle:nil]))
		return nil;
	
	_textView = textView;
	_findRanges = [[NSMutableIndexSet alloc] init];
	_findOptionsViewController = [[RSFindOptionsViewController alloc] init];
	[_findOptionsViewController setDelegate:self];
	_replaceString = @"";
	
	return self;
}

- (void)performCleanup; {
	[[NSNotificationCenter defaultCenter] removeObserver:_textStorageDidProcessEditingObservingToken];
	[[NSNotificationCenter defaultCenter] removeObserver:_viewBoundsDidChangeObservingToken];
	[[NSNotificationCenter defaultCenter] removeObserver:_windowDidResizeObservingToken];
}
#pragma mark IBActions
- (IBAction)toggleFindBar:(id)sender; {
	if ([self isFindBarVisible])
		[self hideFindBar:nil];
	else
		[self showFindBar:nil];
}
static const NSTimeInterval kFindBarShowHideDelay = 0.25;
static const NSAnimationCurve kFindBarShowHideAnimationCurve = NSAnimationEaseIn;
- (IBAction)showFindBar:(id)sender; {
	if ([self isFindBarVisible]) {
		[[[self view] window] makeFirstResponder:[self searchField]];
		return;
	}
	
	_textStorageDidProcessEditingObservingToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSTextStorageDidProcessEditingNotification object:[[self textView] textStorage] queue:nil usingBlock:^(NSNotification *note) {
		if (([[note object] editedMask] & NSTextStorageEditedCharacters) == 0)
			return;
		
		if ([_findRanges count]) {
			[_findRanges removeAllIndexes];
			[self performSelector:@selector(_removeFindTextAttributes) withObject:nil afterDelay:0.0];
		}
		
		if (_textStorageDidProcessEditingTimer)
			[_textStorageDidProcessEditingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
		else
			_textStorageDidProcessEditingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(_textStorageDidProcessEditingTimerCallback:) userInfo:nil repeats:NO];
	}];
	_viewBoundsDidChangeObservingToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSViewBoundsDidChangeNotification object:[[[self textView] enclosingScrollView] contentView] queue:nil usingBlock:^(NSNotification *note) {
		NSRange visibleRange = [[self textView] visibleRange];
		
		[self _removeFindTextAttributesInRange:visibleRange];
		[self _addFindTextAttributesInRange:visibleRange];
	}];
	
	[[[[self textView] enclosingScrollView] superview] addSubview:[self view] positioned:NSWindowBelow relativeTo:[[[[[self textView] enclosingScrollView] superview] subviews] objectAtIndex:0]];
	
	NSRect scrollViewFrame = [[[self textView] enclosingScrollView] frame];
	NSRect findBarFrame = [[self view] frame];
	
	_showFindBarAnimation = [[NSViewAnimation alloc] initWithDuration:kFindBarShowHideDelay animationCurve:kFindBarShowHideAnimationCurve];
	[_showFindBarAnimation setDelegate:self];
	[_showFindBarAnimation setAnimationBlockingMode:NSAnimationNonblocking];
	[_showFindBarAnimation setViewAnimations:[NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[self view],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(scrollViewFrame), NSMaxY(scrollViewFrame), NSWidth(scrollViewFrame), NSHeight(findBarFrame))],NSViewAnimationStartFrameKey,[NSValue valueWithRect:NSMakeRect(NSMinX(scrollViewFrame), NSMaxY(scrollViewFrame)-NSHeight(findBarFrame), NSWidth(scrollViewFrame), NSHeight(findBarFrame))],NSViewAnimationEndFrameKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[[self textView] enclosingScrollView],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(scrollViewFrame), NSMinY(scrollViewFrame), NSWidth(scrollViewFrame), NSHeight(scrollViewFrame)-NSHeight(findBarFrame))],NSViewAnimationEndFrameKey, nil], nil]];
	
	[_showFindBarAnimation startAnimation];
}
- (IBAction)hideFindBar:(id)sender; {
	[[[self textView] window] makeFirstResponder:[self textView]];
	[self _removeFindTextAttributes];
	
	NSRect scrollViewFrame = [[[self textView] enclosingScrollView] frame];
	NSRect findBarFrame = [[self view] frame];
	
	_hideFindBarAnimation = [[NSViewAnimation alloc] initWithDuration:kFindBarShowHideDelay animationCurve:kFindBarShowHideAnimationCurve];
	[_hideFindBarAnimation setDelegate:self];
	[_hideFindBarAnimation setAnimationBlockingMode:NSAnimationNonblocking];
	[_hideFindBarAnimation setViewAnimations:[NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[self view],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(scrollViewFrame), NSMaxY(scrollViewFrame)+NSHeight(findBarFrame), NSWidth(findBarFrame), NSHeight(findBarFrame))],NSViewAnimationEndFrameKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[[self textView] enclosingScrollView],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(scrollViewFrame), NSMinY(scrollViewFrame), NSWidth(scrollViewFrame), NSHeight(scrollViewFrame)+NSHeight(findBarFrame))],NSViewAnimationEndFrameKey, nil], nil]];
	
	[_hideFindBarAnimation startAnimation];
}
- (IBAction)toggleFindOptions:(id)sender; {
	if ([[self findOptionsViewController] areFindOptionsVisible])
		[self hideFindOptions:nil];
	else
		[self showFindOptions:nil];
}
- (void)showFindOptions:(id)sender {
	NSRect rect = [(NSSearchFieldCell *)[[self searchField] cell] searchButtonRectForBounds:[[self searchField] bounds]];
	[[self findOptionsViewController] showFindOptionsViewRelativeToRect:rect ofView:[self searchField] preferredEdge:NSMaxYEdge];
}
- (IBAction)hideFindOptions:(id)sender; {
	[[self findOptionsViewController] hideFindOptionsView];
}

- (IBAction)toggleReplaceControls:(id)sender; {
	if ([self areReplaceControlsVisible])
		[self hideReplaceControls:nil];
	else
		[self showReplaceControls:nil];
}

static const CGFloat kReplaceControlsHeight = 22.0;
- (IBAction)showReplaceControls:(id)sender; {
    if (!self.textView.isEditable) {
        [self setViewMode:RSFindBarViewControllerViewModeFindAndReplace];
        [self setViewMode:RSFindBarViewControllerViewModeFind];
        
        return;
    }
	else if ([self areReplaceControlsVisible]) {
		[self showFindBar:nil];
		return;
	}
	else if (![self isFindBarVisible]) {
		_findFlags.runShowReplaceControlsAnimationAfterShowFindBarAnimationCompletes = YES;
		[self showFindBar:nil];
		return;
	}
	
	[self setViewMode:RSFindBarViewControllerViewModeFindAndReplace];
	
	NSRect scrollViewFrame = [[[self textView] enclosingScrollView] frame];
	NSRect findBarFrame = [[self view] frame];
	
	_showReplaceControlsAnimation = [[NSViewAnimation alloc] initWithDuration:kFindBarShowHideDelay animationCurve:kFindBarShowHideAnimationCurve];
	[_showReplaceControlsAnimation setDelegate:self];
	[_showReplaceControlsAnimation setAnimationBlockingMode:NSAnimationNonblocking];
	[_showReplaceControlsAnimation setViewAnimations:[NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[self view],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(findBarFrame), NSMinY(findBarFrame)-kReplaceControlsHeight, NSWidth(findBarFrame), NSHeight(findBarFrame)+kReplaceControlsHeight)],NSViewAnimationEndFrameKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[[self textView] enclosingScrollView],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(scrollViewFrame), NSMinY(scrollViewFrame), NSWidth(scrollViewFrame), NSHeight(scrollViewFrame)-kReplaceControlsHeight)],NSViewAnimationEndFrameKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceTextField],NSViewAnimationTargetKey,NSViewAnimationFadeInEffect,NSViewAnimationEffectKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceAllButton],NSViewAnimationTargetKey,NSViewAnimationFadeInEffect,NSViewAnimationEffectKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceButton],NSViewAnimationTargetKey,NSViewAnimationFadeInEffect,NSViewAnimationEffectKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceAndFindButton],NSViewAnimationTargetKey,NSViewAnimationFadeInEffect,NSViewAnimationEffectKey, nil], nil]];
	
	[_showReplaceControlsAnimation startAnimation];
}
- (IBAction)hideReplaceControls:(id)sender; {
	if (![self areReplaceControlsVisible]) {
		
		return;
	}
	
	[[[self textView] window] makeFirstResponder:[self searchField]];
	
	NSRect scrollViewFrame = [[[self textView] enclosingScrollView] frame];
	NSRect findBarFrame = [[self view] frame];
	
	_hideReplaceControlsAnimation = [[NSViewAnimation alloc] initWithDuration:kFindBarShowHideDelay animationCurve:kFindBarShowHideAnimationCurve];
	[_hideReplaceControlsAnimation setDelegate:self];
	[_hideReplaceControlsAnimation setAnimationBlockingMode:NSAnimationNonblocking];
	[_hideReplaceControlsAnimation setViewAnimations:[NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[self view],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(findBarFrame), NSMinY(findBarFrame)+kReplaceControlsHeight, NSWidth(findBarFrame), NSHeight(findBarFrame)-kReplaceControlsHeight)],NSViewAnimationEndFrameKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[[self textView] enclosingScrollView],NSViewAnimationTargetKey,[NSValue valueWithRect:NSMakeRect(NSMinX(scrollViewFrame), NSMinY(scrollViewFrame), NSWidth(scrollViewFrame), NSHeight(scrollViewFrame)+kReplaceControlsHeight)],NSViewAnimationEndFrameKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceTextField],NSViewAnimationTargetKey,NSViewAnimationFadeOutEffect,NSViewAnimationEffectKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceAllButton],NSViewAnimationTargetKey,NSViewAnimationFadeOutEffect,NSViewAnimationEffectKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceButton],NSViewAnimationTargetKey,NSViewAnimationFadeOutEffect,NSViewAnimationEffectKey, nil],[NSDictionary dictionaryWithObjectsAndKeys:[self replaceAndFindButton],NSViewAnimationTargetKey,NSViewAnimationFadeOutEffect,NSViewAnimationEffectKey, nil], nil]];
	
	[_hideReplaceControlsAnimation startAnimation];
}

- (IBAction)find:(id)sender; {
	[self _findAndHighlightNearestRange:YES highlightMatches:YES];
}
- (IBAction)findNext:(id)sender; {
	if (![[self findString] length]) {
		NSBeep();
		return;
	}
	
	BOOL didWrap = NO;
	NSRange foundRange = [self _nextRangeDidWrap:&didWrap includeSelectedRange:NO];
	
	if (foundRange.location == NSNotFound) {
		NSBeep();
		
		if (![self wrapAround])
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindNoWrapIndicator"] centeredInView:[[self textView] enclosingScrollView]];
	}
	else {
		[[self textView] setSelectedRange:foundRange];
		[[self textView] scrollRangeToVisible:foundRange];
		[[self textView] showFindIndicatorForRange:foundRange];
		
		if (didWrap)
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicator"] centeredInView:[[self textView] enclosingScrollView]];
	}
}
- (IBAction)findPrevious:(id)sender; {
	if (![[self findString] length]) {
		NSBeep();
		return;
	}
	
	BOOL didWrap = NO;
	NSRange foundRange = [self _previousRangeDidWrap:&didWrap];
	
	if (foundRange.location == NSNotFound) {
		NSBeep();
		
		if (![self wrapAround])
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindNoWrapIndicatorReverse"] centeredInView:[[self textView] enclosingScrollView]];
	}
	else {
		[[self textView] setSelectedRange:foundRange];
		[[self textView] scrollRangeToVisible:foundRange];
		[[self textView] showFindIndicatorForRange:foundRange];
		
		if (didWrap)
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicatorReverse"] centeredInView:[[self textView] enclosingScrollView]];
	}
}
- (IBAction)findNextOrPrevious:(NSSegmentedControl *)sender; {
	if ([sender selectedSegment] == 0)
		[self findPrevious:nil];
	else
		[self findNext:nil];
}
- (IBAction)replaceAll:(id)sender; {
	if (![[self findString] length]) {
		NSBeep();
		return;
	}
	else if (![_findRanges count]) {
		[self _findAndHighlightNearestRange:NO highlightMatches:NO];
		if (![_findRanges count]) {
			NSBeep();
			return;
		}
	}
	
	NSUInteger rangeIndex, rangeCount = [_findRanges count];
	NSMutableArray *replaceRanges = [NSMutableArray arrayWithCapacity:rangeCount];
	NSMutableArray *replaceStrings = [NSMutableArray arrayWithCapacity:rangeCount];
	
	[_findRanges enumerateRangesUsingBlock:^(NSRange replaceRange, BOOL *stop) {
		[replaceRanges addObject:[NSValue valueWithRange:replaceRange]];
		
		NSString *replaceString;
		if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual)
			replaceString = [self replaceString];
		else
			replaceString = [[self findRegularExpression] stringByReplacingMatchesInString:[[[self textView] string] substringWithRange:replaceRange] options:0 range:NSMakeRange(0, replaceRange.length) withTemplate:[self replaceString]];
		
		[replaceStrings addObject:replaceString];
	}];
	
	if ([[self textView] shouldChangeTextInRanges:replaceRanges replacementStrings:replaceStrings]) {
		[[[self textView] textStorage] beginEditing];
		
		for (rangeIndex=[replaceRanges count]-1; rangeIndex>0; rangeIndex--) {
			NSRange replaceRange = [[replaceRanges objectAtIndex:rangeIndex] rangeValue];
			
			[[self textView] replaceCharactersInRange:replaceRange withString:[replaceStrings objectAtIndex:rangeIndex]];
		}
		
		[[[self textView] textStorage] endEditing];
		[[self textView] didChangeText];
	}
	
	if (rangeCount == 1)
		[self setStatusString:NSLocalizedString(@"replaced 1 match", @"replace all 1 match status format string")];
	else
		[self setStatusString:[NSString stringWithFormat:NSLocalizedString(@"replaced %lu matches", @"replace all multiple matches status format string"),rangeCount]];
}
- (IBAction)replace:(id)sender; {
	if (![[self findString] length]) {
		NSBeep();
		return;
	}
	
	BOOL didWrap;
	NSRange replaceRange = [self _nextRangeDidWrap:&didWrap includeSelectedRange:YES];
	
	if (replaceRange.location == NSNotFound) {
		NSBeep();
		
		if (![self wrapAround])
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindNoWrapIndicator"] centeredInView:[[self textView] enclosingScrollView]];
	}
	else {
		[[self textView] setSelectedRange:replaceRange];
		[[self textView] scrollRangeToVisible:replaceRange];
		
		NSString *replaceString;
		if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual)
			replaceString = [self replaceString];
		else
			replaceString = [[self findRegularExpression] stringByReplacingMatchesInString:[[[self textView] string] substringWithRange:replaceRange] options:0 range:NSMakeRange(0, replaceRange.length) withTemplate:[self replaceString]];
		
		if ([[self textView] shouldChangeTextInRange:replaceRange replacementString:replaceString]) {
			[[self textView] replaceCharactersInRange:replaceRange withString:replaceString];
			[[self textView] didChangeText];
		}
		
		if (didWrap)
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicator"] centeredInView:[[self textView] enclosingScrollView]];
	}
}
- (IBAction)replaceAndFind:(id)sender; {
	if (![[self findString] length]) {
		NSBeep();
		return;
	}
	
	BOOL didWrap;
	NSRange replaceRange = [self _nextRangeDidWrap:&didWrap includeSelectedRange:YES];
	
	if (replaceRange.location == NSNotFound) {
		NSBeep();
		
		if (![self wrapAround])
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindNoWrapIndicator"] centeredInView:[[self textView] enclosingScrollView]];
	}
	else {
		[[self textView] setSelectedRange:replaceRange];
		[[self textView] scrollRangeToVisible:replaceRange];
		
		NSString *replaceString;
		if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual)
			replaceString = [self replaceString];
		else
			replaceString = [[self findRegularExpression] stringByReplacingMatchesInString:[[[self textView] string] substringWithRange:replaceRange] options:0 range:NSMakeRange(0, replaceRange.length) withTemplate:[self replaceString]];
		
		if ([[self textView] shouldChangeTextInRange:replaceRange replacementString:replaceString]) {
			[[self textView] replaceCharactersInRange:replaceRange withString:replaceString];
			[[self textView] didChangeText];
		}
		
		[self findNext:nil];
		
		if (didWrap)
			[[RSBezelWidgetManager sharedWindowController] showImage:[NSImage imageNamed:@"FindWrapIndicator"] centeredInView:[[self textView] enclosingScrollView]];
	}
}
#pragma mark Properties
@synthesize searchField=_searchField;
@synthesize replaceTextField=_replaceTextField;
@synthesize replaceAllButton=_replaceAllButton;
@synthesize replaceButton=_replaceButton;
@synthesize replaceAndFindButton=_replaceAndFindButton;

@synthesize findString=_findString;
@synthesize findRegularExpression=_findRegularExpression;
@synthesize replaceString=_replaceString;
@synthesize statusString=_statusString;
@dynamic wrapAround;
- (BOOL)wrapAround {
	return [[self findOptionsViewController] wrapAround];
}
- (void)setWrapAround:(BOOL)wrapAround {
	[[self findOptionsViewController] setWrapAround:wrapAround];
}
@dynamic findBarVisible;
- (BOOL)isFindBarVisible {
	return ([[self view] window] != nil);
}
@dynamic replaceControlsVisible;
- (BOOL)areReplaceControlsVisible {
	return ([self viewMode] == RSFindBarViewControllerViewModeFindAndReplace);
}
@synthesize viewMode=_viewMode;
@synthesize textView=_textView;
@synthesize findOptionsViewController=_findOptionsViewController;
#pragma mark *** Private Methods ***
- (void)_findAndHighlightNearestRange:(BOOL)highlightNearestRange highlightMatches:(BOOL)highlightMatches; {
	[self setStatusString:nil];
	[_findRanges removeAllIndexes];
	[self _removeFindTextAttributesInRange:[[self textView] visibleRange]];
	
	if (![[self findString] length]) {
		NSBeep();
		return;
	}
	else if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleRegularExpression) {
		NSRegularExpressionOptions regexOptions = 0;
		if (![[self findOptionsViewController] matchCase])
			regexOptions |= NSRegularExpressionCaseInsensitive;
		if ([[self findOptionsViewController] anchorsMatchLines])
			regexOptions |= NSRegularExpressionAnchorsMatchLines;
		if ([[self findOptionsViewController] dotMatchesNewlines])
			regexOptions |= NSRegularExpressionDotMatchesLineSeparators;
		
		NSRegularExpression *findRegex = [NSRegularExpression regularExpressionWithPattern:[self findString] options:regexOptions error:NULL];
		if (!findRegex) {
			[self setFindRegularExpression:nil];
			return;
		}
		[self setFindRegularExpression:findRegex];
	}
	
	NSString *string = [[self textView] string];
	NSUInteger stringLength = [string length];
	NSRange searchRange = NSMakeRange(0, stringLength);
	NSStringCompareOptions options = ([[self findOptionsViewController] matchCase])?NSLiteralSearch:(NSCaseInsensitiveSearch|NSLiteralSearch);
	RSFindOptionsMatchStyle matchStyle = [[self findOptionsViewController] matchStyle];
	__block NSUInteger numberOfMatches = 0;
	
	if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual) {
		CFLocaleRef currentLocale = CFLocaleCopyCurrent();
		// the CFStringTokenizer documentation says to pass kCFStringTokenizerUnitWordBoundary to do whole word searching
		CFStringTokenizerRef stringTokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef)string, CFRangeMake(0, (CFIndex)stringLength), kCFStringTokenizerUnitWordBoundary, currentLocale);
		// release the copy of the current locale we were given
		CFRelease(currentLocale);
		
		while (searchRange.location < stringLength) {
			NSRange foundRange = [string rangeOfString:[self findString] options:options range:searchRange];
			if (foundRange.location == NSNotFound)
				break;
			
			CFStringTokenizerGoToTokenAtIndex(stringTokenizer, (CFIndex)foundRange.location);
			CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(stringTokenizer);
			
			switch (matchStyle) {
					// token range doesn't matter in this case
				case RSFindOptionsMatchStyleContains:
					[_findRanges addIndexesInRange:foundRange];
					numberOfMatches++;
					break;
					// token range and found range starting indexes must match and match range can't be longer than token range
				case RSFindOptionsMatchStyleStartsWith:
					if (foundRange.location == tokenRange.location &&
						foundRange.length < tokenRange.length) {
						
						[_findRanges addIndexesInRange:foundRange];
						numberOfMatches++;
					}
					break;
					// the ending indexes of token range and found range must match
				case RSFindOptionsMatchStyleEndsWith:
					if (NSMaxRange(foundRange) == (tokenRange.location + tokenRange.length)) {
						
						[_findRanges addIndexesInRange:foundRange];
						numberOfMatches++;
					}
					break;
					// token range and found range must match exactly
				case RSFindOptionsMatchStyleWholeWord:
					if (foundRange.location == tokenRange.location &&
						foundRange.length == tokenRange.length) {
						
						[_findRanges addIndexesInRange:foundRange];
						numberOfMatches++;
					}
					break;
				default:
					break;
			}
			
			searchRange = NSMakeRange(NSMaxRange(foundRange), stringLength-NSMaxRange(foundRange));
		}
		
		// release our tokenizer from above
		CFRelease(stringTokenizer);
	}
	else {
		[[self findRegularExpression] enumerateMatchesInString:string options:0 range:searchRange usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange foundRange = [result range];
			
			[_findRanges addIndexesInRange:foundRange];
			numberOfMatches++;
		}];
	}
	
	if (!numberOfMatches) {
		[self setStatusString:NSLocalizedString(@"Not found", @"Not found")];
		return;
	}
	else if (numberOfMatches == 1)
		[self setStatusString:NSLocalizedString(@"1 match", @"1 match")];
	else
		[self setStatusString:[NSString stringWithFormat:NSLocalizedString(@"%lu matches", @"find bar multiple matches status string"),numberOfMatches]];
	
	NSMutableArray *recentSearches = [[[[self searchField] recentSearches] mutableCopy] autorelease];
	
	if (![recentSearches containsObject:[self findString]]) {
		[recentSearches addObject:[self findString]];
		[[self searchField] setRecentSearches:recentSearches];
	}
	
	if ([_findRanges count]) {
		if (highlightMatches)
			[self _addFindTextAttributesInRange:[[self textView] visibleRange]];
		
		if (highlightNearestRange) {
			NSRange nearRange = [self _nextRangeDidWrap:NULL includeSelectedRange:YES];
			
			[[self textView] setSelectedRange:nearRange];
			[[self textView] scrollRangeToVisible:nearRange];
			[[self textView] showFindIndicatorForRange:nearRange];
			
			NSPasteboard *findPboard = [NSPasteboard pasteboardWithName:NSFindPboard];
			
			[findPboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
			[findPboard setString:[self findString] forType:NSPasteboardTypeString];
		}
	}
}
- (void)_addFindTextAttributes {	
	[self _addFindTextAttributesInRange:NSMakeRange(0, [[[self textView] string] length])];
}
- (void)_removeFindTextAttributes {
	[self _removeFindTextAttributesInRange:NSMakeRange(0, [[[self textView] string] length])];
}
- (void)_addFindTextAttributesInRange:(NSRange)range; {
	
	NSDictionary *attributes = WCTransparentFindTextAttributes();
	
	[_findRanges enumerateRangesInRange:range options:0 usingBlock:^(NSRange range, BOOL *stop) {
		[[[self textView] layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
	}];
	 
}
- (void)_removeFindTextAttributesInRange:(NSRange)range; {
	[[[self textView] layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:range];
	[[[self textView] layoutManager] removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:range];
	[[[self textView] layoutManager] removeTemporaryAttribute:NSUnderlineColorAttributeName forCharacterRange:range];
}

- (NSRange)_nextRangeDidWrap:(BOOL *)didWrap includeSelectedRange:(BOOL)includeSelectedRange; {
	NSString *string = [[self textView] string];
	NSRange selectedRange = [[self textView] selectedRange];
	NSRange searchRange = (includeSelectedRange)?NSMakeRange(selectedRange.location, [string length]-selectedRange.location):NSMakeRange(NSMaxRange(selectedRange), [string length]-NSMaxRange(selectedRange));
	NSStringCompareOptions options = NSLiteralSearch;
	NSRange foundRange;
	
	if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual) {
		options = ([[self findOptionsViewController] matchCase])?NSLiteralSearch:(NSCaseInsensitiveSearch|NSLiteralSearch);
		foundRange = [[[self textView] string] rangeOfString:[self findString] options:options range:searchRange];
	}
	else
		foundRange = [[self findRegularExpression] rangeOfFirstMatchInString:[[self textView] string] options:0 range:searchRange];
	
	if (foundRange.location == NSNotFound && [self wrapAround]) {
		if (didWrap != NULL)
			*didWrap = YES;
		
		if (includeSelectedRange)
			searchRange = NSMakeRange(0, NSMaxRange(selectedRange));
		else
			searchRange = NSMakeRange(0, selectedRange.location);
		
		if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual)
			foundRange = [[[self textView] string] rangeOfString:[self findString] options:options range:searchRange];
		else
			foundRange = [[self findRegularExpression] rangeOfFirstMatchInString:[[self textView] string] options:0 range:searchRange];
	}
	return foundRange;
}
- (NSRange)_previousRangeDidWrap:(BOOL *)didWrap; {
	NSRange selectedRange = [[self textView] selectedRange];
	NSStringCompareOptions options = NSLiteralSearch;
	NSRange foundRange;
	
	if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual) {
		options = ([[self findOptionsViewController] matchCase])?(NSLiteralSearch|NSBackwardsSearch):(NSBackwardsSearch|NSCaseInsensitiveSearch|NSLiteralSearch);
		foundRange = [[[self textView] string] rangeOfString:[self findString] options:options range:NSMakeRange(0, selectedRange.location)];
	}
	else {
		// TODO: this might be really slow, but i don't know another way to get the last match from NSRegularExpression
		NSArray *foundMatches = [[self findRegularExpression] matchesInString:[[self textView] string] options:0 range:NSMakeRange(0, selectedRange.location)];
		NSTextCheckingResult *lastMatch = [foundMatches lastObject];
		if (lastMatch)
			foundRange = [lastMatch range];
		else
			foundRange = NSNotFoundRange;
	}
	
	if (foundRange.location == NSNotFound && [self wrapAround]) {
		if (didWrap != NULL)
			*didWrap = YES;
		
		if ([[self findOptionsViewController] findStyle] == RSFindOptionsFindStyleTextual)
			foundRange = [[[self textView] string] rangeOfString:[self findString] options:options range:NSMakeRange(NSMaxRange(selectedRange), [[[self textView] string] length]-NSMaxRange(selectedRange))];
		else {
			// TODO: this might be really slow, but i don't know another way to get the last match from NSRegularExpression
			NSArray *foundMatches = [[self findRegularExpression] matchesInString:[[self textView] string] options:0 range:NSMakeRange(NSMaxRange(selectedRange), [[[self textView] string] length]-NSMaxRange(selectedRange))];
			NSTextCheckingResult *lastMatch = [foundMatches lastObject];
			if (lastMatch)
				foundRange = [lastMatch range];
			else
				foundRange = NSNotFoundRange;
		}
	}
	return foundRange;
}
#pragma mark Callbacks
- (void)_textStorageDidProcessEditingTimerCallback:(NSTimer *)timer {
	[_textStorageDidProcessEditingTimer invalidate];
	_textStorageDidProcessEditingTimer = nil;
	
	[self _findAndHighlightNearestRange:NO highlightMatches:NO];
}
@end
