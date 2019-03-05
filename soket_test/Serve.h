//
//  Serve.h
//  soket_test
//
//  Created by dongliang on 2019/3/5.
//  Copyright © 2019年 dl. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ServeMsgBlock)(NSString *msg);

@interface Serve : NSObject

@property (nonatomic, copy) ServeMsgBlock serveMsg;

///创建单利
+(id)shareServe;
///监听本地端口
-(void)openService;

-(void)serveGetMSG:(ServeMsgBlock)serveMsg;

@end

NS_ASSUME_NONNULL_END
