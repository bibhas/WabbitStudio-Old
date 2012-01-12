//
//  RSTreeNode.m
//  WabbitStudio
//
//  Created by William Towe on 1/10/12.
//  Copyright (c) 2012 Revolution Software. All rights reserved.
//

#import "RSTreeNode.h"

NSString *const RSTreeNodeClassNameKey = @"className";

static NSString *const RSTreeNodeChildNodesKey = @"childNodes";

@interface RSTreeNode ()
@property (readwrite,assign,nonatomic) id parentNode;
@end

@implementation RSTreeNode
#pragma mark *** Subclass Overrides ***
- (void)dealloc {
	[_representedObject release];
	_parentNode = nil;
	[_childNodes release];
	[super dealloc];
}
#pragma mark RSPlistArchiving
- (NSDictionary *)plistRepresentation {
	NSMutableArray *childNodePlists = [NSMutableArray arrayWithCapacity:[[self childNodes] count]];
	for (RSTreeNode *node in [self childNodes])
		[childNodePlists addObject:[node plistRepresentation]];
	return [NSDictionary dictionaryWithObjectsAndKeys:[self className],RSTreeNodeClassNameKey,childNodePlists,RSTreeNodeChildNodesKey, nil];
}
- (id)initWithPlistRepresentation:(NSDictionary *)plistRepresentation {
	if (![self initWithRepresentedObject:nil])
		return nil;
	
	for (NSDictionary *nodePlist in [plistRepresentation objectForKey:RSTreeNodeChildNodesKey]) {
		Class nodeClass = NSClassFromString([nodePlist objectForKey:RSTreeNodeClassNameKey]);
		id node = [[nodeClass alloc] initWithPlistRepresentation:nodePlist];
		
		if (node)
			[[self mutableChildNodes] addObject:node];
		
		[node release];
	}
	
	return self;
}
#pragma mark *** Public Methods ***
+ (id)treeNodeWithRepresentedObject:(id)representedObject; {
	return [[[[self class] alloc] initWithRepresentedObject:representedObject] autorelease];
}
- (id)initWithRepresentedObject:(id)representedObject; {
	if (!(self = [super init]))
		return nil;
	
	_childNodes = [[NSMutableArray alloc] initWithCapacity:0];
	_representedObject = [representedObject retain];
	
	return self;
}

- (BOOL)isDescendantOfNode:(RSTreeNode *)node; {
	return [[node descendantNodes] containsObject:self];
}
#pragma mark Properties
@synthesize parentNode=_parentNode;
@synthesize childNodes=_childNodes;
@dynamic mutableChildNodes;
- (NSMutableArray *)mutableChildNodes {
	return [self mutableArrayValueForKey:RSTreeNodeChildNodesKey];
}
- (NSUInteger)countOfChildNodes {
	return [_childNodes count];
}
- (id)objectInChildNodesAtIndex:(NSUInteger)index {
	return [_childNodes objectAtIndex:index];
}
- (NSArray *)childNodesAtIndexes:(NSIndexSet *)indexes {
	return [_childNodes objectsAtIndexes:indexes];
}
- (void)insertChildNodes:(NSArray *)array atIndexes:(NSIndexSet *)indexes {
	for (RSTreeNode *node in array)
		[node setParentNode:self];
	[_childNodes insertObjects:array atIndexes:indexes];
}
- (void)removeChildNodesAtIndexes:(NSIndexSet *)indexes {
	for (RSTreeNode *node in [_childNodes objectsAtIndexes:indexes])
		[node setParentNode:nil];
	[_childNodes removeObjectsAtIndexes:indexes];
}
- (void)replaceChildNodesAtIndexes:(NSIndexSet *)indexes withChildNodes:(NSArray *)array {
	for (RSTreeNode *node in [_childNodes objectsAtIndexes:indexes])
		[node setParentNode:nil];
	for (RSTreeNode *node in array)
		[node setParentNode:self];
	
	[_childNodes replaceObjectsAtIndexes:indexes withObjects:array];
}
@synthesize representedObject=_representedObject;
@dynamic leafNode;
- (BOOL)isLeafNode {
	return (![[self childNodes] count]);
}
@dynamic indexPath;
- (NSIndexPath *)indexPath {
	if (![self parentNode])
		return [NSIndexPath indexPathWithIndex:0];
	return [[[self parentNode] indexPath] indexPathByAddingIndex:[[[self parentNode] childNodes] indexOfObjectIdenticalTo:self]];
}

@dynamic descendantNodes;
- (NSArray *)descendantNodes {
	NSMutableArray *retval = [NSMutableArray arrayWithCapacity:[[self childNodes] count]];
	for (RSTreeNode *node in [self childNodes]) {
		[retval addObject:node];
		
		if (![node isLeafNode])
			[retval addObjectsFromArray:[node descendantNodes]];
	}
	return [[retval copy] autorelease];
}
@dynamic descendantNodesInclusive;
- (NSArray *)descendantNodesInclusive {
	return [[self descendantNodes] arrayByAddingObject:self];
}
@dynamic descendantGroupNodes;
- (NSArray *)descendantGroupNodes {
	NSMutableArray *retval = [NSMutableArray arrayWithCapacity:[[self childNodes] count]];
	for (RSTreeNode *node in [self childNodes]) {
		if (![node isLeafNode]) {
			[retval addObject:node];
			[retval addObjectsFromArray:[node descendantGroupNodes]];
		}
	}
	return [[retval copy] autorelease];
}
@dynamic descendantGroupNodesInclusive;
- (NSArray *)descendantGroupNodesInclusive {
	if ([self isLeafNode])
		return nil;
	return [[self descendantGroupNodes] arrayByAddingObject:self];
}
@dynamic descendantLeafNodes;
- (NSArray *)descendantLeafNodes {
	NSMutableArray *retval = [NSMutableArray arrayWithCapacity:[[self childNodes] count]];
	for (RSTreeNode *node in [self childNodes]) {
		if ([node isLeafNode])
			[retval addObject:node];
		else
			[retval addObjectsFromArray:[node descendantLeafNodes]];
	}
	return [[retval copy] autorelease];
}
@dynamic descendantLeafNodesInclusive;
- (NSArray *)descendantLeafNodesInclusive {
	if ([self isLeafNode])
		return [NSArray arrayWithObject:self];
	return [self descendantLeafNodes];
}

@end