//
//  UDPSocket.m
//  VTH264examples
//
//  Created by 强新宇 on 2016/10/9.
//  Copyright © 2016年 srd. All rights reserved.
//

#import "UDPSocket.h"
#import <arpa/inet.h>
#import <netdb.h>


@interface VideoData : NSObject
@property (nonatomic, strong)NSData * data;
@property (nonatomic, assign)NSInteger tag;
@property (nonatomic, assign)BOOL isComplete;
@property (nonatomic, assign)BOOL isStart;
@property (nonatomic, assign)BOOL isEnd;


- (instancetype)initWithData:(NSData *)data tag:(NSInteger)tag isComplete:(BOOL)isComplete isStart:(BOOL)isStart isEnd:(BOOL)isEnd;
@end

@implementation VideoData

- (instancetype)initWithData:(NSData *)data tag:(NSInteger)tag isComplete:(BOOL)isComplete isStart:(BOOL)isStart isEnd:(BOOL)isEnd
{
    self = [super init];
    if (self) {
        self.data = data;
        self.tag = tag;
        self.isComplete = isComplete;
        self.isStart = isStart;
        self.isEnd = isEnd;
    }
    return self;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"tag => %ld, isStat => %d, isEnd => %d, isComplete => %d",self.tag,self.isStart,self.isEnd,self.isComplete];
}
@end


@interface UDPSocket () <GCDAsyncUdpSocketDelegate>
{
    ikcpcb * kcp;
}

@property (nonatomic, strong)NSMutableArray * receiveArray;
@property (nonatomic, strong)NSMutableDictionary * sendDataDic;


@property (nonatomic, assign)NSInteger  sendTag;
@property (nonatomic, assign)NSInteger  playTag;



@property (nonatomic, strong)NSMutableDictionary * completeDic;
@property (nonatomic, strong)NSMutableDictionary * uncompleteDic;







@end

static unsigned int conv = 10086;
@implementation UDPSocket

+ (UDPSocket *)shareUDPSocket
{
    static UDPSocket * socket = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        socket = [[UDPSocket alloc] init];
    });
    return socket;
}

int udp_output(const char * buf, int len, ikcpcb * kcp, void * user)
{
    UDPSocket * socket = (__bridge UDPSocket *)(user);
    
    [socket.udpSendSocket sendData:[NSData dataWithBytes:buf length:len] toHost:host port:port withTimeout:-1 tag:0];

    NSLog(@"---- %s ---- %d ---- %@ ---- %@",buf,len,kcp,user);
    
    return 1;
}


- (instancetype)init
{
    if ([super init]) {
        [self initSocket];
        self.completeDic = @{}.mutableCopy;
        self.uncompleteDic = @{}.mutableCopy;
        self.sendDataDic = @{}.mutableCopy;
        self.playTag = 1;
        
        kcp = ikcp_create(conv, (__bridge void *)(self));
        
        kcp->output = udp_output;
        
        ikcp_update(kcp, 10);
        
        
        

    }
    return self;
}



- (void)initSocket
{
    
    self.udpReceiveSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    NSError * error = nil;
    [self.udpReceiveSocket bindToPort:port error:&error];
    [self.udpReceiveSocket beginReceiving:&error];

    
    self.udpSendSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
}


- (void)didReceiveDataWithBlock:(DidReceiveDataBlock)block
{
    self.didReceiveDataBlock = block;
}


//在数据后面加上 2个BOOL， 第一个标记是否是 一帧的开头，第二个标记是否是完整的一帧
- (void)senData:(NSData *)data
{

    
    
    
//    NSMutableData * sendData = data.mutableCopy;
//    BOOL isStart = true;
//    [sendData appendBytes:&isStart length:1];
//    BOOL isEnd = true;
//    [sendData appendBytes:&isEnd length:1];
//    BOOL isComplete = true;
//    [sendData appendBytes:&isComplete length:1];
//    
//    [self sendData:sendData];

    //分包
    if (data.length * 8 > 1500) {
        NSInteger len = 1024;

        for (int i = 0; i < data.length / len; i ++) {
            NSInteger rangeLen = 1024;
            if (i == data.length / len - 1) {
                rangeLen = data.length % len;
            }
            
            NSMutableData * sendData = [data subdataWithRange:NSMakeRange(i * len, rangeLen)].mutableCopy;
//            BOOL isStart = i == 0;
//            [sendData appendBytes:&isStart length:1];
//            BOOL isEnd = (i == data.length / len - 1);
//            [sendData appendBytes:&isEnd length:1];
//            BOOL isComplete = false;
//            [sendData appendBytes:&isComplete length:1];
//            [self sendData:sendData];
            
            int a = ikcp_send(kcp, sendData.bytes, sizeof(sendData.bytes));
            NSLog(@" -- ikcp_send => %d",a);


        }
    } else {
        int a = ikcp_send(kcp, data.bytes, sizeof(data.bytes));

        NSLog(@" -- ikcp_send => %d",a);
//        NSMutableData * sendData = data.mutableCopy;
//        BOOL isStart = true;
//        [sendData appendBytes:&isStart length:1];
//        BOOL isEnd = true;
//        [sendData appendBytes:&isEnd length:1];
//        BOOL isComplete = true;
//        [sendData appendBytes:&isComplete length:1];
//
//        [self sendData:sendData];
    }
}

//在数据后面加上 tag
- (void)sendData:(NSData *)data
{
    self.sendTag ++;
    
    NSInteger tag = self.sendTag;
    
    NSMutableData * sendData = data.mutableCopy;
    
    [sendData appendBytes:&tag length:16];
    
    [self.sendDataDic setValue:sendData forKey:@(self.sendTag).stringValue];
    [self.udpSendSocket sendData:sendData toHost:host port:port withTimeout:-1 tag:self.sendTag];
}
#pragma mark -------------------------------------------------------------
#pragma mark Delegate

/**
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * However, you may optionally choose to connect to a particular host for reasons
 * outlined in the documentation for the various connect methods listed above.
 *
 * This method is called if one of the connect methods are invoked, and the connection is successful.
 **/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
    NSLog(@" --- 连接成功");
}

/**
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * However, you may optionally choose to connect to a particular host for reasons
 * outlined in the documentation for the various connect methods listed above.
 *
 * This method is called if one of the connect methods are invoked, and the connection fails.
 * This may happen, for example, if a domain name is given for the host and the domain name is unable to be resolved.
 **/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error
{
    NSLog(@" --- 连接失败");
}

/**
 * Called when the datagram with the given tag has been sent.
 **/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    NSLog(@" --- 发送成功  tag ===> %ld",tag);
}

/**
 * Called if an error occurs while trying to send a datagram.
 * This could be due to a timeout, or something more serious such as the data being too large to fit in a sigle packet.
 **/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    NSLog(@" --- 发送失败 -- %@",error);
}

/**
 * Called when the socket has received the requested datagram.
 **/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(nullable id)filterContext
{
    
    ikcp_input(kcp, data.bytes, sizeof(data.bytes));

 
    
//    if (data.length < 20) {
//        NSInteger tag = 0;
//        [data getBytes:&tag range:NSMakeRange(0, data.length)];
//        
//        [self.sendDataDic removeObjectForKey:@(tag).stringValue];
//        
//        return;
//    }
//    NSData * receiveData = [data subdataWithRange:NSMakeRange(0, data.length - 19)];
//    
//    NSInteger tag = 0;
//    [data getBytes:&tag range:NSMakeRange(data.length - 16, 16)];
//    
//    
//    BOOL isComplete = 0;
//    [data getBytes:&isComplete range:NSMakeRange(data.length - 17, 1)];
//    
//    
//    BOOL isStart = 0;
//    [data getBytes:&isStart range:NSMakeRange(data.length - 19, 1)];
//    
//    
//    
//    BOOL isEnd = 0;
//    [data getBytes:&isEnd range:NSMakeRange(data.length - 18, 1)];
//    
//    
//    NSData * sendData = [NSData dataWithBytes:&tag length:16];
//    
//    [self.udpSendSocket sendData:sendData withTimeout:-1 tag:0];
//    
//    VideoData * video = [[VideoData alloc] initWithData:receiveData tag:tag isComplete:isComplete isStart:isStart isEnd:isEnd];
//    
////    if (video) {
////        [self.completeDic setValue:video forKey:@(video.tag).stringValue];
////    }
//    
////    [self getData];
//    
//    !self.didReceiveDataBlock?:self.didReceiveDataBlock(receiveData);

}

- (void)getData
{
    NSMutableData * data = nil;
    VideoData * video = self.completeDic[@(self.playTag).stringValue];
    NSLog(@" %ld--- %@",self.playTag,video);
    if (video != nil) {
        data = video.data.mutableCopy;

        if (video.isComplete) {
            NSLog(@"%ld --- video data is Complete", self.playTag);
            self.playTag ++;
            [self.completeDic removeObjectForKey:@(self.playTag).stringValue];
        } else {
            NSLog(@"%ld --- video data is  unComplete", self.playTag);

            if (video.isStart) {
                
                NSLog(@"%ld --- video data is Start", self.playTag);

                NSInteger tag = self.playTag;
                while (1) {
                    VideoData * nextVideo = self.completeDic[@(++tag).stringValue];
                    
                    NSLog(@"%ld -tag => %ld-- nextVideo => %@", self.playTag,tag,nextVideo);

                    if (nextVideo) {
                        if (nextVideo.isStart == 0) {
                            if (nextVideo.isEnd == 0) {
                                [data appendData:nextVideo.data];
                            } else {
                                
                                for (NSInteger i = self.playTag + 1; i <= tag;  i++) {
//                                    [self.completeDic setValue:nil forKey:@(i).stringValue];
                                }
                                NSLog(@"%ld ---next video data is end",self.playTag);

                                self.playTag = tag;
                                break;
                            }
                        }
                    } else {
                        NSLog(@"%ld --- next video data is nil",self.playTag);
                        
                        
                        [NSTimer scheduledTimerWithTimeInterval:.2 repeats:NO block:^(NSTimer * _Nonnull timer) {
                            
                            !self.didReceiveDataBlock?:self.didReceiveDataBlock(data);

                            self.playTag = tag;
                            VideoData * nextVideo = self.completeDic[@(++self.playTag).stringValue];
                            
                            if (nextVideo.isStart) {
                                return ;
                            }
                        }];
                        
                        return;
                    }
                }
            } else {
                return;
            }
            
        }
    } else {
        self.playTag ++;

//        [NSTimer scheduledTimerWithTimeInterval:.1 repeats:NO block:^(NSTimer * _Nonnull timer) {
//            
//            self.playTag ++;
//        }];
    }
    
    if (data) {
        NSLog(@"%ld --- 去解析", self.playTag);
        !self.didReceiveDataBlock?:self.didReceiveDataBlock(data);
    } else {
        NSLog(@" %ld--- 空的", self.playTag);
    }

}




/**
 * Called when the socket is closed.
 **/
- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    if (error) {
        NSLog(@"连接中断");
    } else {
        NSLog(@" 连接断开");
    }
}


- (NSMutableArray *)receiveArray
{
    if (!_receiveArray) {
        _receiveArray = @[].mutableCopy;
    }
    return _receiveArray;
}

@end
