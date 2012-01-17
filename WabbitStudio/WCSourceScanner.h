//
//  WCSourceScanner.h
//  WabbitEdit
//
//  Created by William Towe on 12/23/11.
//  Copyright (c) 2011 Revolution Software. All rights reserved.
//

#import <Foundation/NSObject.h>
#import "WCSourceScannerDelegate.h"

extern NSString *const WCSourceScannerDidFinishScanningNotification;
extern NSString *const WCSourceScannerDidFinishScanningSymbolsNotification;

@class NDTrie;

@interface WCSourceScanner : NSObject {
	__weak NSTextStorage *_textStorage;
	__weak id <WCSourceScannerDelegate> _delegate;
	NSOperationQueue *_operationQueue;
	NSArray *_tokens;
	BOOL _needsToScanSymbols;
	NSArray *_symbols;
	NSArray *_symbolsSortedByName;
	NSDictionary *_labelNamesToLabelSymbols;
	NSDictionary *_equateNamesToEquateSymbols;
	NSDictionary *_defineNamesToDefineSymbols;
	NSDictionary *_macroNamesToMacroSymbols;
	NDTrie *_completions;
	NSTimer *_scanTimer;
}
@property (readwrite,assign,nonatomic) id <WCSourceScannerDelegate> delegate;
@property (readonly,nonatomic) NSTextStorage *textStorage;
@property (readwrite,copy) NSArray *tokens;

@property (readwrite,assign,nonatomic) BOOL needsToScanSymbols;
@property (readwrite,copy) NSArray *symbols;
@property (readwrite,copy) NSArray *symbolsSortedByName; 
@property (readwrite,copy) NSDictionary *labelNamesToLabelSymbols;
@property (readwrite,copy) NSDictionary *equateNamesToEquateSymbols;
@property (readwrite,copy) NSDictionary *defineNamesToDefineSymbols;
@property (readwrite,copy) NSDictionary *macroNamesToMacroSymbols;
@property (readwrite,copy) NDTrie *completions;

- (id)initWithTextStorage:(NSTextStorage *)textStorage;

- (void)scanTokens;

+ (NSRegularExpression *)commentRegularExpression;
+ (NSRegularExpression *)multilineCommentRegularExpression;
+ (NSRegularExpression *)mnemonicRegularExpression;
+ (NSRegularExpression *)registerRegularExpression;
+ (NSRegularExpression *)directiveRegularExpression;
+ (NSRegularExpression *)numberRegularExpression;
+ (NSRegularExpression *)binaryRegularExpression;
+ (NSRegularExpression *)hexadecimalRegularExpression;
+ (NSRegularExpression *)preProcessorRegularExpression;
+ (NSRegularExpression *)stringRegularExpression;
+ (NSRegularExpression *)labelRegularExpression;
+ (NSRegularExpression *)equateRegularExpression;
+ (NSRegularExpression *)conditionalRegularExpression;
+ (NSRegularExpression *)defineRegularExpression;
+ (NSRegularExpression *)macroRegularExpression;
+ (NSRegularExpression *)symbolRegularExpression;
@end
