//
//  PHAPIRequest.m
//  playhaven-sdk-ios
//
//  Created by Jesus Fernandez on 3/30/11.
//  Copyright 2011 Playhaven. All rights reserved.
//

#import "PHAPIRequest.h"

#import "NSObject+QueryComponents.h"
#import "PHStringUtil.h"
#import "JSONKit.h"
#import "UIDevice+HardwareString.h"
#import "PHConstants.h"

@interface PHAPIRequest(Private)
+(NSMutableSet *)allRequests;
-(void)finish;
@end

@implementation PHAPIRequest

+(NSMutableSet *)allRequests{
    static NSMutableSet *allRequests = nil;
    
    if (allRequests == nil) {
        allRequests = [[NSMutableSet alloc] init];
    }
    
    return allRequests;
}

+(void)cancelAllRequestsWithDelegate:(id)delegate{
    NSEnumerator *allRequests = [[PHAPIRequest allRequests] objectEnumerator];
    PHAPIRequest *request = nil;
    
    NSMutableSet *canceledRequests = [NSMutableSet set];
    
    while (request = [allRequests nextObject]){
        if ([[request delegate] isEqual:delegate]) {
            [canceledRequests addObject:request];
        }
    }
    
    [canceledRequests makeObjectsPerformSelector:@selector(cancel)];
}

+(NSString *) base64SignatureWithString:(NSString *)string{
  return [PHStringUtil b64DigestForString:string];
}

+(id) requestForApp:(NSString *)token secret:(NSString *)secret{
  return [[[[self class] alloc] initWithApp:token secret:secret] autorelease];
}

-(id) initWithApp:(NSString *)token secret:(NSString *)secret{
  if ((self = [super init])) {
    _token = [token copy];
    _secret = [secret copy];
  }
  
  return self;
}

@synthesize token = _token, secret = _secret;
@synthesize delegate = _delegate;
@synthesize urlPath = _urlPath;
@synthesize additionalParameters = _additionalParameters;
@synthesize hashCode = _hashCode;

-(NSURL *) URL{
  if (_URL == nil) {
    NSString *urlString = [NSString stringWithFormat:@"%@?%@",
                           [self urlPath],
                           [self signedParameterString]];
    _URL = [[NSURL alloc] initWithString:urlString]; 
  }
  
  return _URL;
}

-(NSDictionary *) signedParameters{
  if (_signedParameters == nil) {
    NSString
    *device = [[UIDevice currentDevice] uniqueIdentifier],
    *nonce = [PHStringUtil uuid],
    *signatureHash = [NSString stringWithFormat:@"%@:%@:%@:%@", self.token, device, nonce, self.secret],
    *signature = [PHAPIRequest base64SignatureWithString:signatureHash],
    *appId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
    *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
    *hardware = [[UIDevice currentDevice] hardware],
    *os = [NSString stringWithFormat:@"%@ %@",
           [[UIDevice currentDevice] systemName],
           [[UIDevice currentDevice] systemVersion]];
    if(!appVersion) appVersion = @"NA";
    
    NSNumber 
    *idiom = [NSNumber numberWithInt:(int)UI_USER_INTERFACE_IDIOM()],
    *connection = [NSNumber numberWithInt:PHNetworkStatus()];
    
    
    NSMutableDictionary *additionalParams = (!!self.additionalParameters)? [self.additionalParameters mutableCopy]: [[NSMutableDictionary alloc] init];  
    NSDictionary *signatureParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                     device, @"device",
                                     self.token, @"token",
                                     signature, @"signature",
                                     nonce, @"nonce",
                                     appId, @"app",
                                     hardware,@"hardware",
                                     os,@"os",
                                     idiom,@"idiom",
                                     appVersion, @"app_version",
                                     connection,@"connection",
                                     PH_SDK_VERSION, @"sdk-ios",
                                     nil];
    
    [additionalParams addEntriesFromDictionary:signatureParams];
    _signedParameters = additionalParams;
  }

  return _signedParameters;       
}

-(NSString *) signedParameterString{
  return [[self signedParameters] stringFromQueryComponents];
}

-(void) dealloc{
  [_token release], _token = nil;
  [_secret release], _secret = nil;
  [_URL release], _URL = nil;
  [_connection release], _connection = nil;
  [_signedParameters release], _signedParameters = nil;
  [_connectionData release], _connectionData = nil;
  [_urlPath release], _urlPath = nil;
  [_additionalParameters release], _additionalParameters = nil;
  [super dealloc];
}

#pragma mark -
#pragma mark PHPublisherOpenRequest

-(void) send{
  if (_connection == nil) {
    PH_LOG(@"Sending request: %@", [self.URL absoluteString]);
    NSURLRequest *request = [NSURLRequest requestWithURL:self.URL 
                                             cachePolicy:NSURLRequestReturnCacheDataElseLoad 
                                         timeoutInterval:PH_REQUEST_TIMEOUT];
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [_connection start];
    
    //REQUEST_RETAIN see REQUEST_RELEASE
    [[PHAPIRequest allRequests] addObject:self];
  }
}

-(void)cancel{
    PH_LOG(@"%@ canceled!", NSStringFromClass([self class]));
    [self finish];
}

/*
 * Internal cleanup method
 */
-(void)finish{
    [_connection cancel];
    
    //REQUEST_RELEASE see REQUEST_RETAIN
    [[PHAPIRequest allRequests] removeObject:self];
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    PH_LOG(@"Request recieved HTTP response: %d", [httpResponse statusCode]);
  }
  
  /* We want to get response objects for everything */
  [_connectionData release], _connectionData = [[NSMutableData alloc] init];
  [_response release], _response = nil;
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
  [_connectionData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
  PH_NOTE(@"Request finished!");
  if (!!self.delegate) {

    JSONDecoder *decoder = [[JSONDecoder alloc] initWithParseOptions:JKParseOptionNone];
    [self processRequestResponse:[decoder objectWithUTF8String:[_connectionData bytes] length:[_connectionData length]]];
    [decoder release];
  }
  
  //REQUEST_RELEASE see REQUEST_RETAIN
  [self finish];
}

-(void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
  PH_LOG(@"Request failed with error: %@", [error localizedDescription]);
  [self didFailWithError:error];
    
  //REQUEST_RELEASE see REQUEST_RETAIN
  [self finish];
}

#pragma mark -
-(void)processRequestResponse:(NSDictionary *)responseData{
  id errorValue = [responseData valueForKey:@"error"];
  if (!!errorValue && ![errorValue isEqual:[NSNull null]]) {
    PH_LOG(@"Error response: %@", errorValue);
    [self didFailWithError:PHCreateError(PHAPIResponseErrorType)];
  } else {
    id responseValue = [responseData valueForKey:@"response"]; 
    if ([responseValue isEqual:[NSNull null]]) {
      responseValue = nil;
    }
    [self didSucceedWithResponse:responseValue];
  }
}

-(void)didSucceedWithResponse:(NSDictionary *)responseData{
  if ([self.delegate respondsToSelector:@selector(request:didSucceedWithResponse:)]) {
    [self.delegate performSelector:@selector(request:didSucceedWithResponse:) withObject:self withObject:responseData];
  }
}

-(void)didFailWithError:(NSError *)error{
  if ([self.delegate respondsToSelector:@selector(request:didFailWithError:)]) {
    [self.delegate performSelector:@selector(request:didFailWithError:) withObject:self withObject:error];
  }
}

@end
