//
//  WCFold.m
//  WabbitStudio
//
//  Created by William Towe on 1/24/12.
//  Copyright (c) 2012 Revolution Software. All rights reserved.
//

#import "WCFold.h"

@implementation WCFold
- (NSString *)description {
	return [NSString stringWithFormat:@"range: %@ level: %lu contentRange: %@",NSStringFromRange([self range]),[self level],NSStringFromRange([self contentRange])];
}

+ (id)foldOfType:(WCFoldType)type level:(NSUInteger)level range:(NSRange)range contentRange:(NSRange)contentRange; {
	return [[[[self class] alloc] initWithType:type level:level range:range contentRange:contentRange] autorelease];
}
- (id)initWithType:(WCFoldType)type level:(NSUInteger)level range:(NSRange)range contentRange:(NSRange)contentRange; {
	if (!(self = [super initWithRepresentedObject:nil]))
		return nil;
	
	_type = type;
	_level = level;
	_range = range;
	_contentRange = contentRange;
	
	return self;
}

@synthesize type=_type;
@synthesize range=_range;
@synthesize contentRange=_contentRange;
@synthesize level=_level;
- (void)setLevel:(NSUInteger)level {
	_level = level;
	
	for (WCFold *fold in [self childNodes])
		[fold setLevel:level+1];
}

@end
