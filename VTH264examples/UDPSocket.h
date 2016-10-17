//
//  UDPSocket.h
//  VTH264examples
//
//  Created by 强新宇 on 2016/10/9.
//  Copyright © 2016年 srd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h" // for UDP

#include "ikcp.h"


typedef void(^DidReceiveDataBlock)(NSData * data);



@interface UDPSocket : NSObject

@property (nonatomic, strong)GCDAsyncUdpSocket * udpReceiveSocket;



+ (UDPSocket *)shareUDPSocket;


@property (nonatomic, copy)DidReceiveDataBlock didReceiveDataBlock;
- (void)didReceiveDataWithBlock:(DidReceiveDataBlock)block;



- (void)senData:(NSData *)data;
@end
