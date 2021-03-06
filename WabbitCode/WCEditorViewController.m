//
//  WCEditorViewController.m
//  WabbitEdit
//
//  Created by William Towe on 12/28/11.
//  Copyright (c) 2011 Revolution Software.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "WCEditorViewController.h"
#import "EncodingManager.h"
#import "NSUserDefaults+RSExtensions.h"

NSString *const WCEditorShowCurrentLineHighlightKey = @"editorShowCurrentLineHighlight";
NSString *const WCEditorShowCodeFoldingRibbonKey = @"editorShowCodeFoldingRibbon";
NSString *const WCEditorFocusFollowsSelectionKey = @"editorFocusFollowsSelection";
NSString *const WCEditorShowInvisibleCharactersKey = @"editorShowInvisibleCharacters";
NSString *const WCEditorShowLineNumbersKey = @"editorShowLineNumbers";
NSString *const WCEditorShowMatchingBraceHighlightKey = @"editorShowMatchingBraceHighlight";
NSString *const WCEditorShowMatchingTemporaryLabelHighlightKey = @"editorShowMatchingTemporaryLabelHighlight";
NSString *const WCEditorShowHighlightEnclosedMacroArgumentsKey = @"editorHighlightEnclosedMacroArguments";
NSString *const WCEditorShowHighlightEnclosedMacroArgumentsDelayKey = @"editorHighlightEnclosedMacroArgumentsDelay";
NSString *const WCEditorAutomaticallyInsertMatchingBraceKey = @"editorAutomaticallyInsertMatchingBrace";
NSString *const WCEditorSuggestCompletionsWhileTypingKey = @"editorSuggestCompletionsWhileTyping";
NSString *const WCEditorSuggestCompletionsWhileTypingDelayKey = @"editorSuggestCompletionsWhileTypingDelay";
NSString *const WCEditorAutomaticallyIndentAfterNewlinesKey = @"editorAutomaticallyIndentAfterNewlines";
NSString *const WCEditorAutomaticallyIndentAfterLabelsKey = @"editorAutomaticallyIndentAfterLabels";
NSString *const WCEditorWrapLinesToEditorWidthKey = @"editorWrapLinesToEditorWidth";
NSString *const WCEditorIndentUsingKey = @"editorIndentUsing";
NSString *const WCEditorTabWidthKey = @"editorTabWidth";
NSString *const WCEditorShowPageGuideAtColumnKey = @"editorShowPageGuideAtColumn";
NSString *const WCEditorPageGuideColumnNumberKey = @"editorPageGuideColumnNumber";
NSString *const WCEditorDefaultLineEndingsKey = @"editorDefaultLineEndings";
NSString *const WCEditorConvertExistingFileLineEndingsOnSaveKey = @"editorConvertExistingFileLineEndingsOnSave";
NSString *const WCEditorDefaultTextEncodingKey = @"editorDefaultTextEncoding";

@implementation WCEditorViewController

#pragma mark *** Subclass Overrides ***
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (id)init {
	return [self initWithNibName:[self nibName] bundle:nil];
}

- (NSString *)nibName {
	return @"WCEditorView";
}

- (void)loadView {
	[super loadView];
	
	NSStringEncoding defaultEncoding = [[[NSUserDefaults standardUserDefaults] objectForKey:WCEditorDefaultTextEncodingKey] unsignedIntegerValue];
	[[EncodingManager sharedInstance] setupPopUpCell:[[self popUpButton] cell] selectedEncoding:defaultEncoding withDefaultEntry:NO];
	
	[[self highlightEnclosedMacroArgumentsDelayStepper] setIncrement:0.1];
	[[self suggestCompletionsDelayStepper] setIncrement:0.1];
}
#pragma mark RSPreferencesModule
- (NSString *)identifier {
	return @"org.revsoft.wabbitcode.editor";
}

- (NSString *)label {
	return NSLocalizedString(@"Editor", @"Editor");
}

- (NSImage *)image {
	return [NSImage imageNamed:@"Editor"];
}
#pragma mark RSUserDefaultsProvider
+ (NSDictionary *)userDefaults {
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],WCEditorShowCurrentLineHighlightKey,[NSNumber numberWithBool:YES],WCEditorShowLineNumbersKey,[NSNumber numberWithBool:YES],WCEditorShowMatchingBraceHighlightKey,[NSNumber numberWithBool:YES],WCEditorShowMatchingTemporaryLabelHighlightKey,[NSNumber numberWithBool:YES],WCEditorAutomaticallyInsertMatchingBraceKey,[NSNumber numberWithBool:YES],WCEditorSuggestCompletionsWhileTypingKey,[NSNumber numberWithFloat:0.35],WCEditorSuggestCompletionsWhileTypingDelayKey,[NSNumber numberWithBool:YES],WCEditorAutomaticallyIndentAfterNewlinesKey,[NSNumber numberWithBool:YES],WCEditorWrapLinesToEditorWidthKey,[NSNumber numberWithUnsignedInteger:WCEditorIndentUsingTabs],WCEditorIndentUsingKey,[NSNumber numberWithUnsignedInteger:4],WCEditorTabWidthKey,[NSNumber numberWithUnsignedInteger:100],WCEditorPageGuideColumnNumberKey,[NSNumber numberWithUnsignedInteger:NSUTF8StringEncoding],WCEditorDefaultTextEncodingKey,[NSNumber numberWithBool:YES],WCEditorAutomaticallyIndentAfterLabelsKey,[NSNumber numberWithBool:NO],WCEditorShowInvisibleCharactersKey,[NSNumber numberWithBool:NO],WCEditorShowHighlightEnclosedMacroArgumentsKey,[NSNumber numberWithFloat:0.25],WCEditorShowHighlightEnclosedMacroArgumentsDelayKey,[NSNumber numberWithBool:YES],WCEditorShowCodeFoldingRibbonKey, nil];
}
#pragma mark *** Public Methods ***
#pragma mark IBActions
- (IBAction)changeDefaultTextEncoding:(id)sender; {
	NSStringEncoding selectedEncoding = [[sender representedObject] unsignedIntegerValue];
	
	if (selectedEncoding == NoStringEncoding)
		return;
	
	[[NSUserDefaults standardUserDefaults] setUnsignedInteger:selectedEncoding forKey:WCEditorDefaultTextEncodingKey];
}
#pragma mark Properties
@synthesize initialFirstResponder=_initialFirstResponder;
@synthesize popUpButton=_popUpButton;
@synthesize highlightEnclosedMacroArgumentsDelayStepper=_highlightEnclosedMacroArgumentsDelayStepper;
@synthesize suggestCompletionsDelayStepper=_suggestCompletionsDelayStepper;

@end
