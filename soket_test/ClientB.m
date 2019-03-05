//
//  ClientB.m
//  soket_test
//
//  Created by dongliang on 2019/3/5.
//  Copyright © 2019年 dl. All rights reserved.
//

#import "ClientB.h"
#import <GCDAsyncSocket.h>
#define HOST @"127.0.0.1"
#define PORT 8088

///创建并行队列，单利
static dispatch_queue_t CGD_manager_creation_queue() {
    static dispatch_queue_t _CGD_manager_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _CGD_manager_creation_queue = dispatch_queue_create("gcd.mine.queue.ClinetBkey", DISPATCH_QUEUE_CONCURRENT);
    });
    return _CGD_manager_creation_queue;
}

@interface ClientB()<GCDAsyncSocketDelegate>

@property (nonatomic,strong)GCDAsyncSocket *clinetSocket;//客户端Socket
@property (nonatomic, strong)NSThread *connectThread;
@property (nonatomic, strong)NSDictionary *currentPacketHeadDic;

@end

@implementation ClientB

+(id)shareClinetB{
    static ClientB *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [[ClientB alloc] init];
    });
    return client;
}

///连接服务器
-(BOOL)connect{
    self.clinetSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:CGD_manager_creation_queue()];
    NSError *error;
    [self.clinetSocket connectToHost:HOST onPort:PORT error:&error];
    if (!error) {
        return YES;  ///连接成功
    }else{
        return NO;   ///连接失败
    }
}

///给B发消息
-(void)sendMsgToA{
    NSData *data  =  [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data1  = [@"I" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data2  = [@"am" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data3  = [@"B," dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data4  = [@"nice to meet you!" dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data :@"txt" toClinet:@"CinentA"];
    [self sendData:data1 :@"txt" toClinet:@"CinentA"];
    [self sendData:data2 :@"txt" toClinet:@"CinentA"];
    [self sendData:data3 :@"txt" toClinet:@"CinentA"];
    [self sendData:data4 :@"txt" toClinet:@"CinentA"];
}

///封装报文，即消息---先定义一个数据包的头部headDic,里面封装这个数据包的大小和类型信息，自身客户端id和目标客户端id，最后转成json串再转成data
- (void)sendData:(NSData *)data :(NSString *)type toClinet:(NSString *)target{
    NSUInteger size = data.length;
    NSMutableDictionary *headDic = [NSMutableDictionary dictionary];
    [headDic setObject:type forKey:@"type"];
    [headDic setObject:@"CinentB" forKey:@"CinentID"];
    [headDic setObject:target forKey:@"targetID"];
    [headDic setObject:[NSString stringWithFormat:@"%ld",size] forKey:@"size"];
    
    NSString *jsonStr = [self dictionaryToJson:headDic];
    NSData *lengthData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *mData = [NSMutableData dataWithData:lengthData];
    //分界
    [mData appendData:[GCDAsyncSocket CRLFData]];  ///这个的作用就是将头部信息和消息内容区分开来
    [mData appendData:data];   ///最后将真正的数据包给拼接上
    
    //写数据：第二个参数，请求超时时间,设置为-1是无限时间
    [self.clinetSocket writeData:mData withTimeout:-1 tag:0];
}

//字典转为Json字符串
- (NSString *)dictionaryToJson:(NSDictionary *)dic
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma GCDAsyncSocketDelegate
///连接到服务器
-(void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    [self heartBeat];  ///连接上第一时间发送一个心跳包，目的是为了更新服务端里的sokect的ClientID
    if (self.clientBmsg) {
        self.clientBmsg([NSString stringWithFormat:@"%@---连接成功",self.class]);
    }
    ///读取消息
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    ///开启线程发送心跳
    [self.connectThread start];
}

///从服务器读到数据后的处理
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    if (!_currentPacketHeadDic) {
        ///获取到刚才发送数据时封装的头部信息
        _currentPacketHeadDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (!_currentPacketHeadDic) {
            ///当前数据包的头为空
            ///此时你可以断开这个soket连接或者丢弃这个包进行下一个包的读取
            return;
        }
        
        ///这个字典里有size、type、sourceClient,分别代表大小、类型、来源客户端
        NSUInteger packetLength = [_currentPacketHeadDic[@"size"] integerValue];
        ///读取数据包的大小
        [sock readDataToLength:packetLength withTimeout:-1 tag:0];
    }
    
    ///正式包的处理
    NSUInteger packetLength = [_currentPacketHeadDic[@"size"] integerValue];
    if (packetLength <= 0 || data.length != packetLength) {
        ///当前数据包的数据大小不正确
        return;
    }
    
    NSString *type = _currentPacketHeadDic[@"type"];
    NSString *sourceClient = _currentPacketHeadDic[@"sourceClient"];
    if ([type isEqualToString:@"txt"]) {
        ///纯文本消息
        NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (self.clientBmsg) {
            self.clientBmsg([NSString stringWithFormat:@"客户端B收到消息：%@---来自于%@",msg,sourceClient]);
        }
    }else if ([type isEqualToString:@"img"]){
        ///图片消息
        if (self.clientBmsg) {
            self.clientBmsg([NSString stringWithFormat:@"客户端B收到一张图片---来自于%@",sourceClient]);
        }
    }
    
    _currentPacketHeadDic = nil;
    ///继续读取消息
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

#pragma 心跳---保持和服务器的连接
///发送心跳包
-(void)heartBeat{
    NSData *data = [@"B心跳" dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data :@"heart" toClinet:@""];
}

///创建心跳
-(NSThread *)connectThread{
    if (!_connectThread) {
        _connectThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadStart) object:nil];
    }
    return _connectThread;
}

-(void)threadStart{
    @autoreleasepool {
        ///添加计时器，3s发送一次心跳
        [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(heartBeat) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] run];
    }
}

-(void)clientBGetMsg:(clientBMessageBlock)clientBmsg{
     self.clientBmsg = clientBmsg;
}

@end
