//
//  PHPublisherPromosRequest.m
//  playhaven-sdk-ios
//
//  Created by Jesus Fernandez on 4/20/11.
//  Copyright 2011 Playhaven. All rights reserved.
//

#import "PHPublisherPromosRequest.h"
#import "PHConstants.h"

@interface PHAPIRequest(Private)
-(id)initWithApp:(NSString *)token secret:(NSString *)secret;
@end

@interface PHPublisherPromosRequest(Private)
-(id)initWithApp:(NSString *)token secret:(NSString *)secret delegate:(id)delegate;
@end

@implementation PHPublisherPromosRequest

+(id)requestForApp:(NSString *)token secret:(NSString *)secret delegate:(id)delegate{
  return [[[[self class] alloc] initWithApp:token secret:secret delegate:delegate] autorelease];
}

-(id)initWithApp:(NSString *)token secret:(NSString *)secret delegate:(id)delegate{
  if ((self = [self initWithApp:token secret:secret])) {
    self.delegate = delegate;
  }
  
  return self;
}

-(NSString *)urlPath{
  return PH_URL(/v3/publisher/promos/);
}

@end
