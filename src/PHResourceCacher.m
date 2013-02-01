//
//  PHResourceCacher.h
//  playhaven-sdk-ios
//
//  Created by Lilli Szafranski on 1/31/13.
//  Copyright 2013 Playhaven. All rights reserved.
//

#import "PHConnectionManager.h"
#import "PHResourceCacher.h"
#import "PHConstants.h"

@implementation PHResourceCacher
{

}

- (id)initWithThingsToDownload:(id)things
{
    self = [super init];
    if (self)
    {
        for (NSString *urlString in things)
        {
            NSURL *url = [NSURL URLWithString:urlString];
            NSURLRequest *request = [NSURLRequest requestWithURL:url
                                                     cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                 timeoutInterval:PH_REQUEST_TIMEOUT];

            DLog(@"caching content for url: %@", [[request URL] absoluteString]);

            if (![PHConnectionManager isRequestPending:request])
                [PHConnectionManager createConnectionFromRequest:request forDelegate:self withContext:nil];
        }
    }

    return self;
}

+ (id)cacherWithThingsToDownload:(id)things
{
    return [[[PHResourceCacher alloc] initWithThingsToDownload:things] autorelease];
}

- (void)connectionDidFailWithError:(NSError *)error request:(NSURLRequest *)request andContext:(id)context
{

}

- (void)connectionDidFinishLoadingWithRequest:(NSURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data andContext:(id)context
{

}

- (void)connectionWasStoppedWithContext:(id)context
{

}

@end
