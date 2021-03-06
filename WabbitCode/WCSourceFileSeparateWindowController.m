//
//  WCSourceFileSeparateWindowController.m
//  WabbitStudio
//
//  Created by William Towe on 1/29/12.
//  Copyright (c) 2012 Revolution Software.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "WCSourceFileSeparateWindowController.h"
#import "WCTabViewController.h"
#import "WCSourceFileDocument.h"
#import "WCProjectDocument.h"
#import "WCTabViewWindow.h"
#import "NSWindow+ULIZoomEffect.h"
#import "WCProjectWindowController.h"
#import "WCProjectNavigatorViewController.h"
#import "NSTreeController+RSExtensions.h"
#import "RSNavigatorControl.h"

#import <PSMTabBarControl/PSMTabBarControl.h>

@implementation WCSourceFileSeparateWindowController

- (void)dealloc {
	_sourceFileDocument = nil;
	[_tabViewController release];
	[super dealloc];
}

- (NSString *)windowNibName {
	return @"WCSourceFileSeparateWindow";
}

- (void)windowDidLoad {
	[super windowDidLoad];
	
	[(WCTabViewWindow *)[self window] setTabViewController:[self tabViewController]];
	
	[[[self tabViewController] view] setFrameSize:[[[self window] contentView] frame].size];
	[[[self window] contentView] addSubview:[[self tabViewController] view]];
	
	[[[self tabViewController] tabBarControl] setCanCloseOnlyTab:NO];
	
	[[self projectDocument] openTabForSourceFileDocument:[self sourceFileDocument] tabViewContext:self];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
	if ([[[[self tabViewController] tabBarControl] tabView] numberOfTabViewItems])
		return [NSString stringWithFormat:NSLocalizedString(@"%@ - %@",@"source file separate window controller window title format string"),displayName,[[[[[[self tabViewController] tabBarControl] tabView] selectedTabViewItem] identifier] displayName]];
	return displayName;
}
#pragma mark NSWindowDelegate
- (BOOL)windowShouldClose:(id)sender {	
	NSArray *files = [NSArray arrayWithObjects:[[[self projectDocument] sourceFileDocumentsToFiles] objectForKey:[self sourceFileDocument]], nil];
	NSTreeNode *item = [[[[[[self projectDocument] projectWindowController] projectNavigatorViewController] treeController] treeNodesForModelObjects:files] lastObject];
	NSInteger itemRow = [[[[[self projectDocument] projectWindowController] projectNavigatorViewController] outlineView] rowForItem:item];
	WCProjectNavigatorViewController *projectNavigatorViewController = [[[self projectDocument] projectWindowController] projectNavigatorViewController];
	NSTableCellView *view = [[projectNavigatorViewController outlineView] viewAtColumn:0 row:itemRow makeIfNecessary:NO];
	
	if (view && [[[[[self projectDocument] projectWindowController] navigatorControl] selectedItemIdentifier] isEqualToString:WCProjectWindowNavigatorControlProjectItemIdentifier]) {
		NSRect zoomRect = [[view window] convertRectToScreen:[view convertRectToBase:[[view imageView] bounds]]];
		
		[[self window] orderOutWithZoomEffectToRect:zoomRect];
	}
	
	return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
	while ([[[self tabViewController] tabView] numberOfTabViewItems])
		[[[self tabViewController] tabView] removeTabViewItem:[[[self tabViewController] tabView] tabViewItemAtIndex:0]];
}

#pragma mark WCTabViewControllerDelegate
- (WCProjectDocument *)projectDocumentForTabViewController:(WCTabViewController *)tabViewController {
	return [self projectDocument];
}
#pragma mark *** Public Methods ***
- (id)initWithSourceFileDocument:(WCSourceFileDocument *)sourceFileDocument; {
	if (!(self = [super initWithWindowNibName:[self windowNibName]]))
		return nil;
	
	_sourceFileDocument = sourceFileDocument;
	
	_tabViewController = [[WCTabViewController alloc] init];
	[_tabViewController setDelegate:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_tabViewControllerDidCloseTab:) name:WCTabViewControllerDidCloseTabNotification object:_tabViewController];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_tabViewControllerDidSelectTab:) name:WCTabViewControllerDidSelectTabNotification object:_tabViewController];
	
	return self;
}
#pragma mark IBActions
- (IBAction)selectNextTab:(id)sender; {
	NSArray *tabViewItems = [[[self tabViewController] tabBarControl] representedTabViewItems];
	NSTabViewItem *selectedTabViewItem = [[[self tabViewController] tabView] selectedTabViewItem];
	NSUInteger indexOfTabViewItemToSelect;
	
	if (selectedTabViewItem == [tabViewItems lastObject])
		indexOfTabViewItemToSelect = 0;
	else
		indexOfTabViewItemToSelect = [tabViewItems indexOfObject:selectedTabViewItem] + 1;
	
	[[[self tabViewController] tabView] selectTabViewItemAtIndex:indexOfTabViewItemToSelect];
}
- (IBAction)selectPreviousTab:(id)sender; {
	NSArray *tabViewItems = [[[self tabViewController] tabBarControl] representedTabViewItems];
	NSTabViewItem *selectedTabViewItem = [[[self tabViewController] tabView] selectedTabViewItem];
	NSUInteger indexOfTabViewItemToSelect;
	
	if (selectedTabViewItem == [tabViewItems objectAtIndex:0])
		indexOfTabViewItemToSelect = [tabViewItems count] - 1;
	else
		indexOfTabViewItemToSelect = [tabViewItems indexOfObject:selectedTabViewItem] - 1;
	
	[[[self tabViewController] tabView] selectTabViewItemAtIndex:indexOfTabViewItemToSelect];
}
#pragma mark Properties
@synthesize tabViewController=_tabViewController;
@dynamic projectDocument;
- (WCProjectDocument *)projectDocument {
	return [self document];
}
@synthesize sourceFileDocument=_sourceFileDocument;

#pragma mark *** Private Methods ***

#pragma mark Notifications
- (void)_tabViewControllerDidCloseTab:(NSNotification *)note {
	[self synchronizeWindowTitleWithDocumentName];
}
- (void)_tabViewControllerDidSelectTab:(NSNotification *)note {
	[self synchronizeWindowTitleWithDocumentName];
}

@end
