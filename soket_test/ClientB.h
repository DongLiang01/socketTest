//
//  ClientB.h
//  soket_test
//
//  Created by dongliang on 2019/3/5.
//  Copyright © 2019年 dl. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^clientBMessageBlock)(NSString *msg);  ///传消息

@interface ClientB : NSObject

@property (nonatomic, copy) clientBMessageBlock clientBmsg;
///创建单利
+(id)shareClinetB;
///连接服务器
-(BOOL)connect;
///给B发消息
-(void)sendMsgToA;

-(void)clientBGetMsg:(clientBMessageBlock)clientBmsg;

- (void)sendData:(NSData *)data :(NSString *)type toClinet:(NSString *)target;

@end

NS_ASSUME_NONNULL_END
