//
//  WCJumpBarDataSource.h
//  WabbitEdit
//
//  Created by William Towe on 12/26/11.
//  Copyright (c) 2011 Revolution Software. All rights reserved.
//

#import <Foundation/NSObject.h>

@class WCSourceScanner,WCProjectDocument,WCJumpBarComponentCell,WCSourceFileDocument;

@protocol WCJumpBarDataSource <NSObject>
@required
- (WCSourceScanner *)sourceScanner;
- (WCSourceFileDocument *)sourceFileDocument;
- (WCProjectDocument *)projectDocument;
- (NSArray *)jumpBarComponentCells;
- (WCJumpBarComponentCell *)fileComponentCell;
@end