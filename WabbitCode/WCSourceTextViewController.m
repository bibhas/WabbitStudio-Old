//
//  WCSourceTextViewController.m
//  WabbitEdit
//
//  Created by William Towe on 12/26/11.
//  Copyright (c) 2011 Revolution Software.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "WCSourceTextViewController.h"
#import "WCSourceTextView.h"
#import "WCSourceScanner.h"
#import "WCSourceTextStorage.h"
#import "WCSourceRulerView.h"
#import "WCSourceHighlighter.h"
#import "NSTextView+WCExtensions.h"
#import "WCArgumentPlaceholderCell.h"
#import "RSDefines.h"
#import "WCFontAndColorTheme.h"
#import "WCFontAndColorThemeManager.h"
#import "WCEditorViewController.h"
#import "WCJumpBarViewController.h"
#import "WCSourceFileDocument.h"
#import "WCStandardSourceTextViewController.h"
#import "WCSourceSymbol.h"
#import "WCProjectDocument.h"
#import "WCSourceLayoutManager.h"
#import "WCSourceToken.h"
#import "WCArgumentPlaceholderWindowController.h"
#import "WCProjectNavigatorViewController.h"
#import "WCProjectWindowController.h"
#import "WCFoldAttachmentCell.h"
#import "NSArray+WCExtensions.h"
#import "WCSourceTypesetter.h"
#import "WCBuildController.h"
#import "WCSourceScrollView.h"
#import "WCBreakpointManager.h"
#import "RSToolTipManager.h"
#import "RSToolTipProvider.h"
#import "RSNavigatorControl.h"

@interface WCSourceTextViewController ()
@property (readonly,nonatomic) WCSourceScanner *sourceScanner;
@property (readonly,nonatomic) WCStandardSourceTextViewController *standardSourceTextViewController;

@end

@implementation WCSourceTextViewController
#pragma mark *** Subclass Overrides ***
- (void)dealloc {
#ifdef DEBUG
	NSLog(@"%@ called in %@",NSStringFromSelector(_cmd),[self className]);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_standardSourceTextViewController = nil;
	[_jumpBarViewController release];
	_sourceFileDocument = nil;
	[super dealloc];
}

- (NSString *)nibName {
	return @"WCSourceTextView";
}

- (void)loadView {
	[super loadView];
	
	[[self sourceHighlighter] performFullHighlightIfNeeded];
	
	[[[self scrollView] contentView] setAutoresizesSubviews:YES];
	[(WCSourceScrollView *)[self scrollView] setDelegate:self];
	
	WCSourceLayoutManager *layoutManager = [[[WCSourceLayoutManager alloc] init] autorelease];
	
	[layoutManager setDelegate:self];
	
	[[self textStorage] addLayoutManager:layoutManager];
	
	NSSize contentSize = [[self scrollView] contentSize];
	NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:contentSize] autorelease];
	
	[layoutManager addTextContainer:textContainer];
	
	WCSourceTextView *textView = [[[WCSourceTextView alloc] initWithFrame:[[[self scrollView] contentView] frame] textContainer:textContainer] autorelease];
	
	[textView setDelegate:self];
	
	[self setTextView:textView];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:WCEditorWrapLinesToEditorWidthKey]) {
		[[self scrollView] setHasHorizontalScroller:NO];
		[textView setHorizontallyResizable:YES];
		[textContainer setWidthTracksTextView:YES];
		[textContainer setContainerSize:NSMakeSize(contentSize.width, CGFLOAT_MAX)];
	} else {
		[[self scrollView] setHasHorizontalScroller:YES];
		[textView setHorizontallyResizable:YES];
		[textContainer setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
		[textContainer setWidthTracksTextView:NO];
	}
	[textView setTextContainerInset:NSMakeSize(1.0, 0.0)];
	
	[[self scrollView] setDocumentView:textView];
	
	WCSourceRulerView *rulerView = [[[WCSourceRulerView alloc] initWithScrollView:[[self textView] enclosingScrollView] orientation:NSVerticalRuler] autorelease];
	
	[rulerView setClientView:[self textView]];
	[rulerView setDelegate:self];
	
	[[[self textView] enclosingScrollView] setVerticalRulerView:rulerView];
	
	[[[self textView] enclosingScrollView] setHasHorizontalScroller:NO];
	[[[self textView] enclosingScrollView] setHasVerticalRuler:YES];
	[[[self textView] enclosingScrollView] setRulersVisible:YES];
	
	[[self view] addSubview:[[self jumpBarViewController] view]];
	
	NSRect scrollViewFrame = [[self scrollView] frame];
	NSRect jumpBarFrame = [[[self jumpBarViewController] view] frame];
	
	[[self scrollView] setFrame:NSMakeRect(NSMinX(scrollViewFrame), NSMinY(scrollViewFrame), NSWidth(scrollViewFrame), NSHeight(scrollViewFrame)-NSHeight(jumpBarFrame))];
	[[[self jumpBarViewController] view] setFrame:NSMakeRect(NSMinX(scrollViewFrame), NSMaxY(scrollViewFrame)-NSHeight(jumpBarFrame), NSWidth(scrollViewFrame), NSHeight(jumpBarFrame))];
	
	[[[self jumpBarViewController] addAssistantEditorButton] setAction:@selector(addAssistantEditor:)];
	[[[self jumpBarViewController] addAssistantEditorButton] setTarget:self];
	[[[self jumpBarViewController] removeAssistantEditorButton] setAction:@selector(removeAssistantEditor:)];
	[[[self jumpBarViewController] removeAssistantEditorButton] setTarget:self];
	
	[[self textView] setSelectedRange:NSEmptyRange];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_viewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:[[self scrollView] contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_viewBoundsDidChange:) name:NSViewFrameDidChangeNotification object:[[self scrollView] contentView]];
}
#pragma mark NSMenuValidation
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if ([menuItem action] == @selector(revealInProjectNavigator:)) {
		if (![[self sourceFileDocument] projectDocument])
			return NO;
	}
	else if ([menuItem action] == @selector(showInFinder:)) {
		if (![[self sourceFileDocument] fileURL])
			return NO;
	}
    else if ([menuItem action] == @selector(addAssistantEditor:))
        return [[self standardSourceTextViewController] validateMenuItem:menuItem];
    else if ([menuItem action] == @selector(removeAssistantEditor:))
        return [[self standardSourceTextViewController] validateMenuItem:menuItem];
    else if ([menuItem action] == @selector(showStandardEditor:))
        return [[self standardSourceTextViewController] validateMenuItem:menuItem];
    else if ([menuItem action] == @selector(showAssistantEditor:))
        return [[self standardSourceTextViewController] validateMenuItem:menuItem];
	return YES;
}
#pragma mark NSLayoutManagerDelegate
- (void)layoutManagerDidInvalidateLayout:(NSLayoutManager *)sender {

}
#pragma mark NSTextViewDelegate
- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
	if (commandSelector == @selector(insertNewline:)) {
		if ([textView selectedRange].location >= [[textView string] length])
			return NO;
		
		id attachment = [[textView textStorage] attribute:NSAttachmentAttributeName atIndex:[textView selectedRange].location effectiveRange:NULL];
		if ([[attachment attachmentCell] isKindOfClass:[WCArgumentPlaceholderCell class]]) {			
			[self textView:textView doubleClickedOnCell:[attachment attachmentCell] inRect:NSZeroRect atIndex:[textView selectedRange].location];
			return YES;
		}
	}
	return NO;
}

- (void)textView:(NSTextView *)textView clickedOnCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(NSUInteger)charIndex {
	if ([cell isKindOfClass:[WCArgumentPlaceholderCell class]]) {
		[textView setSelectedRange:NSMakeRange(charIndex, 1)];
	}
}
- (void)textView:(NSTextView *)textView doubleClickedOnCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(NSUInteger)charIndex {
	if ([cell isKindOfClass:[WCArgumentPlaceholderCell class]]) {
		if ([[(WCArgumentPlaceholderCell *)cell argumentChoices] count]) {
			WCArgumentPlaceholderWindowController *windowController = [[[WCArgumentPlaceholderWindowController alloc] initWithArgumentPlaceholderCell:(WCArgumentPlaceholderCell *)cell characterIndex:charIndex textView:[self textView]] autorelease];
			
			[windowController showWindow:nil];
		}
		else {
			[textView insertText:[(WCArgumentPlaceholderCell *)cell stringValue] replacementRange:NSMakeRange(charIndex, 1)];
			[textView setSelectedRange:NSMakeRange(charIndex, [[(WCArgumentPlaceholderCell *)cell stringValue] length])];
		}
	}
}
- (NSDictionary *)textView:(NSTextView *)textView shouldChangeTypingAttributes:(NSDictionary *)oldTypingAttributes toAttributes:(NSDictionary *)newTypingAttributes; {
	WCFontAndColorTheme *currentTheme = [[WCFontAndColorThemeManager sharedManager] currentTheme];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:[currentTheme plainTextFont],NSFontAttributeName,[currentTheme plainTextColor],NSForegroundColorAttributeName,[[self textStorage] paragraphStyle],NSParagraphStyleAttributeName, nil];
}
- (NSArray *)textView:(NSTextView *)textView didCheckTextInRange:(NSRange)range types:(NSTextCheckingTypes)checkingTypes options:(NSDictionary *)options results:(NSArray *)results orthography:(NSOrthography *)orthography wordCount:(NSInteger)wordCount {
	NSMutableArray *modifiedResults = [NSMutableArray arrayWithCapacity:[results count]];
	
	for (NSTextCheckingResult *result in results) {
		id tokenType = [[textView textStorage] attribute:WCSourceTokenTypeAttributeName atIndex:[result range].location effectiveRange:NULL];
		
		if ([tokenType unsignedIntValue] == WCSourceTokenTypeComment ||
			[tokenType unsignedIntValue] == WCSourceTokenTypeMultilineComment)
			[modifiedResults addObject:result];
	}
	return modifiedResults;
}
// suppress the tooltips that come from misspelled words
- (NSString *)textView:(NSTextView *)textView willDisplayToolTip:(NSString *)tooltip forCharacterAtIndex:(NSUInteger)characterIndex {
	return nil;
}
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view {
	return [[self sourceFileDocument] undoManager];
}

#pragma mark WCSourceTextViewDelegate
- (NSArray *)sourceSymbolsForSourceTextView:(WCSourceTextView *)textView {
	return [[self sourceScanner] symbols];
}
- (NSArray *)sourceTokensForSourceTextView:(WCSourceTextView *)textView {
	return [[self sourceScanner] tokens];
}
- (NSArray *)macrosForSourceTextView:(WCSourceTextView *)textView; {
	return [[self sourceScanner] macros];
}
- (NSArray *)sourceTextView:(WCSourceTextView *)textView sourceSymbolsForSymbolName:(NSString *)name {
	NSMutableArray *retval = [NSMutableArray arrayWithCapacity:0];
	
	name = [name lowercaseString];
	
	NSArray *labelNamesArray = [[self sourceFileDocument] labelSymbolsForSourceHighlighter:[self sourceHighlighter]];
	NSArray *equateNamesArray = [[self sourceFileDocument] equateSymbolsForSourceHighlighter:[self sourceHighlighter]];
	NSArray *defineNamesArray = [[self sourceFileDocument] defineSymbolsForSourceHighlighter:[self sourceHighlighter]];
	NSArray *macroNamesArray = [[self sourceFileDocument] macroSymbolsForSourceHighlighter:[self sourceHighlighter]];
	
	for (NSDictionary *labelNames in labelNamesArray) {
		if ([labelNames objectForKey:name]) {
			[retval addObjectsFromArray:[[labelNames objectForKey:name] allObjects]];
			break;
		}
	}
	for (NSDictionary *equateNames in equateNamesArray) {
		if ([equateNames objectForKey:name]) {
			[retval addObjectsFromArray:[[equateNames objectForKey:name] allObjects]];
			break;
		}
	}
	for (NSDictionary *defineNames in defineNamesArray) {
		if ([defineNames objectForKey:name]) {
			[retval addObjectsFromArray:[[defineNames objectForKey:name] allObjects]];
			break;
		}
	}
	for (NSDictionary *macroNames in macroNamesArray) {
		if ([macroNames objectForKey:name]) {
			[retval addObjectsFromArray:[[macroNames objectForKey:name] allObjects]];
			break;
		}
	}
	
	[retval sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"range" ascending:YES comparator:^NSComparisonResult(id obj1, id obj2) {
		if ([obj1 rangeValue].location < [obj2 rangeValue].location)
			return NSOrderedAscending;
		else if ([obj1 rangeValue].location > [obj2 rangeValue].location)
			return NSOrderedDescending;
		return NSOrderedSame;
	}]]];
	
	return [[retval copy] autorelease];
}
- (NSArray *)buildIssuesForSourceTextView:(WCSourceTextView *)textView {
	if ([[self sourceFileDocument] projectDocument]) {
		WCFile *file = [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
		
		return [[[[[self sourceFileDocument] projectDocument] buildController] filesToBuildIssuesSortedByLocation] objectForKey:file];
	}
	return nil;
}
- (NSArray *)fileBreakpointsForSourceTextView:(WCSourceTextView *)textView {
	if ([[self sourceFileDocument] projectDocument]) {
		WCFile *file = [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
		
		return [[[[[self sourceFileDocument] projectDocument] breakpointManager] filesToFileBreakpointsSortedByLocation] objectForKey:file];
	}
	return nil;
}
- (WCFile *)fileForSourceTextView:(WCSourceTextView *)textView {
	if ([[self sourceFileDocument] projectDocument])
		return [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
	return nil;
}

- (WCSourceScanner *)sourceScannerForSourceTextView:(WCSourceTextView *)textView {
	return [self sourceScanner];
}
- (WCSourceHighlighter *)sourceHighlighterForSourceTextView:(WCSourceTextView *)textView; {
	return [self sourceHighlighter];
}
- (WCProjectDocument *)projectDocumentForSourceTextView:(WCSourceTextView *)textView; {
	return [[self sourceFileDocument] projectDocument];
}
- (WCSourceFileDocument *)sourceFileDocumentForSourceTextView:(WCSourceTextView *)textView {
	return [self sourceFileDocument];
}
- (void)handleJumpToDefinitionForSourceTextView:(WCSourceTextView *)textView sourceSymbol:(WCSourceSymbol *)symbol {
	if ([symbol sourceScanner] == [self sourceScanner]) {
		[textView setSelectedRange:[symbol range]];
		[textView scrollRangeToVisible:[symbol range]];
	}
	else {
		WCSourceTextViewController *stvController = [[[self sourceFileDocument] projectDocument] openTabForSourceFileDocument:[[[symbol sourceScanner] delegate] sourceFileDocumentForSourceScanner:[symbol sourceScanner]] tabViewContext:nil];
		
		[[stvController textView] setSelectedRange:[symbol range]];
		[[stvController textView] centerSelectionInVisibleArea:nil];
	}
}
- (void)handleJumpToDefinitionForSourceTextView:(WCSourceTextView *)textView file:(WCFile *)file; {
	[[[self sourceFileDocument] projectDocument] openTabForFile:file tabViewContext:nil];
}
#pragma mark WCSourceRulerViewDelegate
- (WCSourceScanner *)sourceScannerForSourceRulerView:(WCSourceRulerView *)rulerView {
	return [self sourceScanner];
}
- (NSArray *)buildIssuesForSourceRulerView:(WCSourceRulerView *)rulerView {
	if ([[self sourceFileDocument] projectDocument]) {
		WCFile *file = [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
		
		return [[[[[self sourceFileDocument] projectDocument] buildController] filesToBuildIssuesSortedByLocation] objectForKey:file];
	}
	return nil;
}
- (WCProjectDocument *)projectDocumentForSourceRulerView:(WCSourceRulerView *)rulerView {
	return [[self sourceFileDocument] projectDocument];
}
- (NSArray *)fileBreakpointsForSourceRulerView:(WCSourceRulerView *)rulerView; {
	if ([[self sourceFileDocument] projectDocument]) {
		WCFile *file = [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
		
		return [[[[[self sourceFileDocument] projectDocument] breakpointManager] filesToFileBreakpointsSortedByLocation] objectForKey:file];
	}
	return nil;
}
- (WCFile *)fileForSourceRulerView:(WCSourceRulerView *)rulerView {
	if ([[self sourceFileDocument] projectDocument])
		return [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
	return nil;
}
#pragma mark WCSourceScrollViewDelegate
- (WCProjectDocument *)projectDocumentForSourceScrollView:(WCSourceScrollView *)scrollView {
	return [[self sourceFileDocument] projectDocument];
}
- (NSArray *)buildIssuesForSourceScrollView:(WCSourceScrollView *)scrollView {
	if ([[self sourceFileDocument] projectDocument]) {
		WCFile *file = [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
		
		return [[[[[self sourceFileDocument] projectDocument] buildController] filesToBuildIssuesSortedByLocation] objectForKey:file];
	}
	return nil;
}
- (WCSourceTextStorage *)sourceTextStorageForSourceScrollView:(WCSourceScrollView *)scrollView {
	return [[self sourceFileDocument] textStorage];
}
#pragma mark *** Public Methods ***
- (id)initWithSourceFileDocument:(WCSourceFileDocument *)sourceFileDocument; {
	return [self initWithSourceFileDocument:sourceFileDocument standardSourceTextViewController:nil];
}
- (id)initWithSourceFileDocument:(WCSourceFileDocument *)sourceFileDocument standardSourceTextViewController:(WCStandardSourceTextViewController *)sourceTextViewController; {
	if (!(self = [super initWithNibName:[self nibName] bundle:nil]))
		return nil;
	
	_sourceFileDocument = sourceFileDocument;
	_standardSourceTextViewController = sourceTextViewController;
	
	return self;
}

- (void)performCleanup; {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[[self textStorage] removeLayoutManager:[[self textView] layoutManager]];
	
	[[self jumpBarViewController] performCleanup];
}
#pragma mark IBActions
- (IBAction)showStandardEditor:(id)sender; {
	[[self standardSourceTextViewController] showStandardEditor:nil];
}
- (IBAction)showTopLevelItems:(id)sender; {
	[[self jumpBarViewController] showTopLevelItems:nil];
}
- (IBAction)showGroupItems:(id)sender; {
	[[self jumpBarViewController] showGroupItems:nil];
}
- (IBAction)showDocumentItems:(id)sender; {
	[[self jumpBarViewController] showDocumentItems:nil];
}
- (IBAction)showAssistantEditor:(id)sender; {
	[[self standardSourceTextViewController] showAssistantEditor:nil];
}
- (IBAction)addAssistantEditor:(id)sender; {
	[[self standardSourceTextViewController] addAssistantEditorForSourceTextViewController:self];
}
- (IBAction)removeAssistantEditor:(id)sender; {
	[[self standardSourceTextViewController] removeAssistantEditorForSourceTextViewController:self];
}

- (IBAction)revealInProjectNavigator:(id)sender; {
	WCFile *file = [[[[self sourceFileDocument] projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]];
	
    [self.sourceFileDocument.projectDocument.projectWindowController.navigatorControl setSelectedItemIdentifier:WCProjectWindowNavigatorControlProjectItemIdentifier];
	[[[[[self sourceFileDocument] projectDocument] projectWindowController] projectNavigatorViewController] setSelectedModelObjects:[NSArray arrayWithObjects:file, nil]];
}
- (IBAction)showInFinder:(id)sender; {
	if (![[self sourceFileDocument] fileURL]) {
		NSBeep();
		return;
	}
	
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:[NSArray arrayWithObjects:[[self sourceFileDocument] fileURL], nil]];
}

- (IBAction)moveFocusToNextArea:(id)sender; {
	[[self standardSourceTextViewController] moveFocusToNextArea:nil];
}
- (IBAction)moveFocusToPreviousArea:(id)sender; {
	[[self standardSourceTextViewController] moveFocusToPreviousArea:nil];
}
#pragma mark Properties
@synthesize textView=_textView;
@synthesize scrollView=_scrollView;
@dynamic sourceScanner;
- (WCSourceScanner *)sourceScanner {
	return [_sourceFileDocument sourceScanner];
}
@dynamic textStorage;
- (WCSourceTextStorage *)textStorage {
	return [_sourceFileDocument textStorage];
}
@dynamic sourceHighlighter;
- (WCSourceHighlighter *)sourceHighlighter {
	return [_sourceFileDocument sourceHighlighter];
}
@dynamic jumpBarViewController;
- (WCJumpBarViewController *)jumpBarViewController {
	if (!_jumpBarViewController) {
		_jumpBarViewController = [[WCJumpBarViewController alloc] initWithTextView:[self textView] jumpBarDataSource:_sourceFileDocument];
	}
	return _jumpBarViewController;
}
@synthesize standardSourceTextViewController=_standardSourceTextViewController;
@synthesize sourceFileDocument=_sourceFileDocument;
#pragma mark *** Private Methods ***

#pragma mark IBActions

#pragma mark Notifications

- (void)_viewBoundsDidChange:(NSNotification *)note {
	[[self sourceHighlighter] highlightSymbolsInRange:[[self textView] visibleRange]];
}
@end
