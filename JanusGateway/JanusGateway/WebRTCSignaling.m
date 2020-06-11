//
//  WebRTCSignaling.m
//  JanusGateway
//
//  Created by xiang on 07/02/2017.
//  Copyright © 2017 dotEngine. All rights reserved.
//

#import "WebRTCSignaling.h"

static NSTimeInterval kXSPeerClientKeepaliveInterval = 10.0;


@interface WebRTCSignaling () <SRWebSocketDelegate>

@property (nonatomic, strong) NSTimer* presenceKeepAliveTimer;


@end

@implementation WebRTCSignaling {
    NSString* _url;
    SRWebSocket *_socekt;
    long sessionID;
    long handleID;
    NSString *transaction;
    BOOL isCreated, isAttached, isRequested;
}

-(instancetype)initWithURL:(NSString *)url delegate:(id<WebRTCSignalingDelegate>)delegate
{
    
    self = [super init];
    isCreated = isAttached = isRequested = false;
    _delegate = delegate;
    _url = url;
    //    _socekt = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:_url]];
    _socekt = [[SRWebSocket alloc]initWithURL:[NSURL URLWithString:_url] protocols:@[@"janus-protocol"]];
    _socekt.delegate = self;
    return self;
}


- (void)setState:(WebRTCSignalingState)state {
    if (_state == state) {
        return;
    }
    _state = state;
    [_delegate channel:self didChangeState:_state];
}


-(void)connect
{
    [_socekt open];
}


-(void)disconnect
{
    if (_state == kSignalingStateClosed || _state == kSignalingStateError) {
        return;
    }
    [_socekt close];
    
    [self setState:kSignalingStateClosed];
    
}

-(void)dealloc
{
    [self disconnect];
}


-(void)sendMessage:(NSDictionary *)message
{
    
    if (_state != kSignalingStateOpen) {
        return;
    }
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [_socekt send:jsonString];
    }
}

-(void)makeSocketRequest
{
    NSDictionary *message = @{
        @"janus": @"message",
        @"session_id":[NSNumber numberWithLong:sessionID],
        @"handle_id": [NSNumber numberWithLong:handleID],
        @"transaction": transaction,
        @"body":@{
                @"request":@"register",
                @"username":@"sip:teTo1np1tt1PazHQAC7UuX2F@172.31.26.209",
                @"secret": @"oq3F9Gt4SS6fS3zT1VoKQy6J",
                @"display_name": @"teTo1np1tt1PazHQAC7UuX2F",
                @"proxy": @"sip:172.31.26.209:5060"
        },
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    
    
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [_socekt send:jsonString];
    }
    //    [_socekt send:message];
}

NSString* randomString(NSInteger len){
    static char* charSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    static int charSetLen = 62;
    uint8_t* buf = malloc(len+1);
    buf[len]=0;
    arc4random_buf(buf, len);
    for (int i = 0; i<len; i++) {
        buf[i] = charSet[buf[i]%charSetLen];
    }
    
    return [[NSString alloc]initWithBytesNoCopy:buf length:len encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

-(void)createJanus
{
    transaction = randomString(12);
    NSDictionary *message = @{@"janus": @"create",@"transaction":transaction};
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    
    
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [_socekt send:jsonString];
    }
    //    [_socekt send:message];
}

-(void)attachJanus
{
    NSDictionary *message = @{
        @"janus":@"attach",
        @"plugin":@"janus.plugin.sip",
        @"session_id": [NSNumber numberWithLong:sessionID],
        @"transaction":transaction
    };
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    
    
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [_socekt send:jsonString];
    }
    //    [_socekt send:message];
}

#pragma mark  - SRWebSocketDelegate

-(void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    self.state = kSignalingStateOpen;
    
    [self scheduleTimer];
    [self createJanus];
}

-(void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSString *messageString = message;
    NSData *messageData = [messageString dataUsingEncoding:NSUTF8StringEncoding];
    id jsonObject = [NSJSONSerialization JSONObjectWithData:messageData
                                                    options:0
                                                      error:nil];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    if (!isCreated) {
        isCreated = true;
        NSDictionary * data = jsonObject[@"data"];
        sessionID = [data[@"id"] longValue];
        //[self makeSocketRequest];
        [self attachJanus];
    } else if (!isAttached) {
        isAttached = true;
        NSDictionary * data = jsonObject[@"data"];
        handleID = [data[@"id"] longValue];
        [self makeSocketRequest];
    }
    
    //    if (sessionID == (int)nil) {
    //        NSDictionary * data = jsonObject[@"data"];
    //        sessionID = [data[@"id"] longValue];
    //        //[self makeSocketRequest];
    //        [self attachJanus];
    //    }
    
    NSDictionary *wssMessage = jsonObject;
    [self.delegate channel:self didReceiveMessage:wssMessage];
    
}

-(void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    self.state = kSignalingStateError;
    NSLog(@"didFailWithError %@", error);
    [self invalidateTimer];
    
}

-(void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    self.state = kSignalingStateClosed;
    NSLog(@"didCloseWithCode %@", reason);
    [self invalidateTimer];
    
}




- (void)scheduleTimer
{
    [self invalidateTimer];
    
    NSTimer *timer = [NSTimer timerWithTimeInterval:kXSPeerClientKeepaliveInterval target:self selector:@selector(handleTimer:) userInfo:nil repeats:NO];
    
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    
    self.presenceKeepAliveTimer = timer;
}


- (void)invalidateTimer
{
    [self.presenceKeepAliveTimer invalidate];
    self.presenceKeepAliveTimer = nil;
}

- (void)handleTimer:(NSTimer *)timer
{
    [self sendPing];
    
    [self scheduleTimer];
}

- (void)sendPing
{
    [_socekt sendPing:nil];
}


@end






















