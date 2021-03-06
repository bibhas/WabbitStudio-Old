//
//  WCSearchNavigatorViewController.h
//  WabbitStudio
//
//  Created by William Towe on 2/6/12.
//  Copyright (c) 2012 Revolution Software.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "JAViewController.h"
#import "WCNavigatorModule.h"
#import "RSFindOptionsViewControllerDelegate.h"
#import "RSOutlineViewDelegate.h"

typedef enum _WCSearchNavigatorViewMode {
	WCSearchNavigatorViewModeFind = 0,
	WCSearchNavigatorViewModeFindAndReplace = 1
	
} WCSearchNavigatorViewMode;

typedef enum _WCSearchNavigatorSearchScope {
	WCSearchNavigatorSearchScopeAllFiles = 0,
	WCSearchNavigatorSearchScopeOpenFiles = 1,
	WCSearchNavigatorSearchScopeSelectedFiles = 2
	
} WCSearchNavigatorSearchScope;

@class WCProjectContainer,WCSearchContainer,RSFindOptionsViewController,WCProjectDocument;

@interface WCSearchNavigatorViewController : NSViewController <WCNavigatorModule,RSFindOptionsViewControllerDelegate,RSOutlineViewDelegate,NSControlTextEditingDelegate,NSAnimationDelegate> {
	__unsafe_unretained WCProjectDocument *_projectDocument;
	WCSearchContainer *_searchContainer;
	WCSearchContainer *_filteredSearchContainer;
	NSString *_filterString;
	NSString *_searchString;
	NSRegularExpression *_searchRegularExpression;
	NSString *_replaceString;
	WCSearchNavigatorSearchScope _searchScope;
	NSString *_statusString;
	RSFindOptionsViewController *_filterOptionsViewController;
	RSFindOptionsViewController *_searchOptionsViewController;
	NSViewAnimation *_showReplaceControlsAnimation;
	NSViewAnimation *_hideReplaceControlsAnimation;
	WCSearchNavigatorViewMode _viewMode;
	NSOperationQueue *_operationQueue;
	struct {
		unsigned int searching:1;
		unsigned int switchTreeControllerContentBinding:1;
		unsigned int RESERVED:30;
	} _searchNavigatorFlags;
}

@property (readwrite,assign,nonatomic) IBOutlet NSOutlineView *outlineView;
@property (readwrite,assign,nonatomic) IBOutlet NSTreeController *treeController;
@property (readwrite,assign,nonatomic) IBOutlet NSSearchField *filterField;
@property (readwrite,assign,nonatomic) IBOutlet NSSearchField *searchField;
@property (readwrite,assign,nonatomic) IBOutlet NSTextField *replaceField;
@property (readwrite,assign,nonatomic) IBOutlet NSButton *replaceButton;
@property (readwrite,assign,nonatomic) IBOutlet NSButton *replaceAllButton;
@property (readwrite,assign,nonatomic) IBOutlet NSView *findView;

@property (readonly,nonatomic) WCSearchContainer *searchContainer;
@property (readonly,retain,nonatomic) WCSearchContainer *filteredSearchContainer;
@property (readwrite,copy,nonatomic) NSString *filterString;
@property (readwrite,copy,nonatomic) NSString *searchString;
@property (readwrite,copy,nonatomic) NSString *statusString;
@property (readwrite,copy,nonatomic) NSString *replaceString;
@property (readwrite,assign,nonatomic) WCSearchNavigatorSearchScope searchScope;
@property (readonly,assign,nonatomic) WCSearchNavigatorViewMode viewMode;
@property (readwrite,assign,nonatomic,getter = isSearching) BOOL searching;
@property (readonly,nonatomic) WCProjectDocument *projectDocument;
@property (readonly,nonatomic) WCProjectContainer *projectContainer;
@property (readonly,nonatomic) RSFindOptionsViewController *searchOptionsViewController;
@property (readonly,retain,nonatomic) NSRegularExpression *searchRegularExpression;

- (id)initWithProjectDocument:(WCProjectDocument *)projectDocument;

- (IBAction)filter:(id)sender;
- (IBAction)search:(id)sender;

- (IBAction)toggleReplaceControls:(id)sender;
- (IBAction)showReplaceControls:(id)sender;
- (IBAction)hideReplaceControls:(id)sender;

- (IBAction)toggleSearchOptions:(id)sender;
- (IBAction)showSearchOptions:(id)sender;
- (IBAction)hideSearchOptions:(id)sender;

- (IBAction)toggleFilterOptions:(id)sender;
- (IBAction)showFilterOptions:(id)sender;
- (IBAction)hideFilterOptions:(id)sender;

- (IBAction)replace:(id)sender;
- (IBAction)replaceAll:(id)sender;

@end
