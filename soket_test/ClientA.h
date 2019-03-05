//
//  ClientA.h
//  soket_test
//
//  Created by dongliang on 2019/3/4.
//  Copyright © 2019年 dl. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^clientAMessageBlock)(NSString *msg);  ///传消息

@interface ClientA : NSObject

@property (nonatomic, copy) clientAMessageBlock clientAmsg;
///创建单利
+(id)shareClinetA;
///连接服务器
-(BOOL)connect;
///给B发消息
-(void)sendMsgToB;

-(void)clientAGetMsg:(clientAMessageBlock)clientAmsg;

- (void)sendData:(NSData *)data :(NSString *)type toClinet:(NSString *)target;

@end

NS_ASSUME_NONNULL_END
