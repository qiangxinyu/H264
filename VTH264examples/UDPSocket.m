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

#import "test.h"


NSInteger tag;
NSInteger tagss;

GCDAsyncUdpSocket * udpSendSocket;
@interface UDPSocket () <GCDAsyncUdpSocketDelegate>

@end
@implementation UDPSocket
ikcpcb * kcp;

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
    NSData * data = [NSData dataWithBytes:buf length:len];
    [udpSendSocket sendData:data toHost:host port:port withTimeout:-1 tag:tagss++];
    
    
    NSLog(@" data --- %@ ,buf -- %s, len --- %d",data,buf,len);
    
    int a;
    [data getBytes:&a length:sizeof(a)];
    
    printf(" --- udp send --- %d \n",a);
    
    return 0;
}


- (instancetype)init
{
    if ([super init]) {
        [self initSocket];
       
    }
    return self;
}
- (void)initSocket
{
    
    self.udpReceiveSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    NSError * error = nil;
    [self.udpReceiveSocket bindToPort:port error:&error];
    [self.udpReceiveSocket beginReceiving:&error];

    udpSendSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    kcp = ikcp_create(port, NULL);
    
    kcp->output = udp_output;
    // 而考虑到丢包重发，设置最大收发窗口为128
    ikcp_wndsize(kcp, 128, 128);
    
    
    ikcp_nodelay(kcp, 1, 10, 2, 1);
    kcp->rx_minrto = 10;
    kcp->fastresend = 1;
    
//    ikcp_setmtu(kcp, 1024 + 24);
    
    
    
    [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer * _Nonnull timer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ikcp_update(kcp,iclock());
        });
    }];
}



- (void)didReceiveDataWithBlock:(DidReceiveDataBlock)block
{
    self.didReceiveDataBlock = block;
}



- (void)senData:(NSData *)data
{
//    !self.didReceiveDataBlock?:self.didReceiveDataBlock(data);

//    //分包
//    if (data.length * 8 > 1500) {
//        NSInteger len = 1024;
//        for (int i = 0; i < data.length / len; i ++) {
//            NSInteger rangeLen = 1024;
//            if (i == data.length / len - 1) {
//                rangeLen = data.length % len;
//            }
//            NSMutableData * sendData = [data subdataWithRange:NSMakeRange(i * len, rangeLen)].mutableCopy;
//            [self ikcpSendData:sendData];
//        }
//    } else {
        [self ikcpSendData:data];
//    }
}


- (void)ikcpSendData:(NSData *)data
{
    
    tag++;
    
    int a = ikcp_send(kcp, data.bytes, (int)data.length);
    NSLog(@" -- ikcp_send => %d  size => %ld tag => %ld  %@",a,data.length,tag, data);
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
    dispatch_async(dispatch_get_main_queue(), ^{
        int input = ikcp_input(kcp, data.bytes, data.length);
        NSLog(@" --- input - %d",input);
        char buffer[1000000];
        int recv = ikcp_recv(kcp, buffer, 1000000);
        
        NSLog(@" --- recv -- %d",recv);
        
        if (recv > 0) {
            NSData * receiveData = [NSData dataWithBytes:buffer length:recv];
            NSLog(@" --- receiveData = %@",receiveData);
            !self.didReceiveDataBlock?:self.didReceiveDataBlock(receiveData);
        }
    });
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




@end
