//
//  Serve.m
//  soket_test
//
//  Created by dongliang on 2019/3/5.
//  Copyright © 2019年 dl. All rights reserved.
//

#import "Serve.h"
#import <GCDAsyncSocket.h>

static dispatch_queue_t GCD_MANAGER_Serve_queue(){
    static dispatch_queue_t _GCD_MANAGER_Serve_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _GCD_MANAGER_Serve_queue = dispatch_queue_create("gcd.mine.queue.Servekey", DISPATCH_QUEUE_CONCURRENT);
    });
    return _GCD_MANAGER_Serve_queue;
}

#pragma 储存在服务器的客户端
@interface Client : NSObject
@property(nonatomic, strong) GCDAsyncSocket *scocket;//客户端scocket
@property(nonatomic, strong) NSDate *timeOfSocket;  //最后更新时间，即心跳时间
@property(nonatomic, strong) NSDictionary *currentPacketHead;//客户端报文字典
@property(nonatomic, copy) NSString *clientID;//客户端ID
@end

@implementation Client

@end

@interface Serve()<GCDAsyncSocketDelegate>

@property(nonatomic, strong)GCDAsyncSocket *serve;
@property(nonatomic, strong)NSThread *checkThread;   //检测心跳
@property(nonatomic, strong)NSMutableArray *clientsArray;  //储存客户端

@end

@implementation Serve

-(NSMutableArray *)clientsArray{
    if (!_clientsArray) {
        _clientsArray = [NSMutableArray array];
    }
    return _clientsArray;
}

+(id)shareServe{
    static Serve *serve;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serve = [[Serve alloc] init];
    });
    return serve;
}

-(instancetype)init{
    if (self = [super init]) {
        self.serve = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:GCD_MANAGER_Serve_queue()];
        self.checkThread = [[NSThread alloc] initWithTarget:self selector:@selector(checkClient) object:nil];
        [self.checkThread start];
    }
    return self;
}

///监控端口
-(void)openService{
    NSError *error;
    BOOL sucess = [self.serve acceptOnPort:8088 error:&error];
    if (sucess) {
        if (self.serveMsg) {
            self.serveMsg([NSString stringWithFormat:@"%@---监控端口成功，等待客户端请求连接。。。",self.class]);
        }
    }else{
        if (self.serveMsg) {
            self.serveMsg([NSString stringWithFormat:@"%@---端口开启失败",self.class]);
        }
    }
}

#pragma GCDAsyncSocketDelegate
///有新的socket连接到本地端口时，会触发这个代理方法
///连接后，我们创建一个新的Client类型的对象，将当前socket交给这个对象，再将这个client用一个数组保存起来，后面会利用数组中保存的Client对象处理心跳、转发、用户调度等操作
///为什么保存：因为所有的客户端都会同时发送心跳包和用户消息，都会调用didReadData方法，比如在用户A对应的socket正在读取报文内容的时候，用户B也调用方法，就会造成我们的数据处理混乱，所以封装一个Client来对应处理每个客户端的事务，各自维持自己处理数据的逻辑，互不干扰
-(void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    if (self.serveMsg) {
        self.serveMsg([NSString stringWithFormat:@"%@-%@ IP: %@ : %hu 客户端请求连接",self.class,newSocket,newSocket.connectedHost,newSocket.connectedPort]);
    }
    ///将客户端保存进数组
    Client *client = [[Client alloc] init];
    client.scocket = newSocket;
    client.timeOfSocket = [NSDate date];
    [self.clientsArray addObject:client];
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

///服务端接收数据的处理
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    Client *client = [self getClientBysocket:sock];
    if (!client) {
        [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
        return;
    }
    if (!client.currentPacketHead) {
        client.currentPacketHead = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (!client.currentPacketHead) {
            if (self.serveMsg) {
                self.serveMsg(@"error: 当前数据包的头部为空");
            }
            ///断开这个socket连接或者丢弃这个包的数据进行下一个包的读取
            return;
        }
        
        NSUInteger packetLength = [client.currentPacketHead[@"size"] integerValue];
        //读到数据包的大小
        [sock readDataToLength:packetLength withTimeout:-1 tag:0];
    }
    
    ///正式包的处理
    NSUInteger packetLength = [client.currentPacketHead[@"size"] integerValue];
    if (packetLength <= 0 || data.length != packetLength) {
        ///当前数据包的大小不正确
        return;
    }
    
    ///获取头部内容
    NSString *clientID = client.currentPacketHead[@"CinentID"];
    client.clientID = clientID;
    NSString *targetID=client.currentPacketHead[@"targetID"];
    NSString *type = client.currentPacketHead[@"type"];
    
    if ([type isEqualToString:@"img"]) {
        if (self.serveMsg) {
            self.serveMsg(@"收到图片");
        }
    }else if([type isEqualToString:@"txt"]){
        NSString *msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        if (self.serveMsg) {
            self.serveMsg([NSString stringWithFormat:@"收到消息:%@",msg]);
        }
    }else if([type isEqualToString:@"heart"]){
        NSString *msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        if (self.serveMsg) {
            self.serveMsg([NSString stringWithFormat:@"收到心跳: %@",msg]);
        }
    }
    
    ///向目标客户端转发消息
    for (Client *socket in self.clientsArray) {
        if ([socket.clientID isEqualToString:targetID]) {
            [self writeDataWithSocket:socket.scocket data:data type:type sourceClient:clientID];
        }
    }
    client.currentPacketHead = nil;
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

///消息转发成功后
-(void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    if (self.serveMsg) {
        self.serveMsg([NSString stringWithFormat:@"%@---数据发送成功",self.class]);
    }
}

///有用户下线后,移除掉数组中保存的对应客户端client
-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    if (self.serveMsg) {
        self.serveMsg([NSString stringWithFormat:@"%@---有用户下线",self.class]);
    }
    NSMutableArray *arrayNew = [NSMutableArray array];
    for (Client *socket in self.clientsArray ) {
        if ([socket.scocket isEqual:sock]) {
            continue;
        }
        [arrayNew addObject:socket];
    }
    self.clientsArray = arrayNew;
}

///根据socket获取对应的client
-(Client *)getClientBysocket:(GCDAsyncSocket *)sock{
    for (Client *socket in self.clientsArray) {
        if ([sock isEqual:socket.scocket]) {
            ///更新最新时间
            socket.timeOfSocket = [NSDate date];
            return socket;
        }
    }
    return nil;
}

///向目标客户端发消息
- (void)writeDataWithSocket:(GCDAsyncSocket*)clientSocket data:(NSData *)data type:(NSString *)type sourceClient:(NSString *)sourceClient {
    NSUInteger size = data.length;
    NSMutableDictionary *headDic = [NSMutableDictionary dictionary];
    [headDic setObject:type forKey:@"type"];
    [headDic setObject:sourceClient forKey:@"sourceClient"];
    [headDic setObject:[NSString stringWithFormat:@"%ld",size] forKey:@"size"];
    NSString *jsonStr = [self dictionaryToJson:headDic];
    NSData *lengthData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *mData = [NSMutableData dataWithData:lengthData];
    //分界
    [mData appendData:[GCDAsyncSocket CRLFData]];
    [mData appendData:data];
    //第二个参数，请求超时时间
    [clientSocket writeData:mData withTimeout:-1 tag:0];
}

//字典转为Json字符串
- (NSString *)dictionaryToJson:(NSDictionary *)dic{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma 检测心跳(每次收到客户端发过来的报文--就会更新下客户端的最后交互时间--也就是属性timeOfSocket--然后每隔一段时间检测服务器保存的所有客户端中的timeOfSocket--和目前时间对比--超出预定的失活时间--就断开对应的socket--杀死客户端)
///开启线程，启动runloop，循环检测客户端sokect的最新time
-(void)checkClient{
    @autoreleasepool {
        [NSTimer scheduledTimerWithTimeInterval:30.f target:self selector:@selector(repeatCheckClinet) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] run];
    }
}

///移除超过心跳检测的客户端
-(void)repeatCheckClinet{
    if (self.clientsArray.count == 0) {
        return;
    }
    
    NSDate *date = [NSDate date];
    NSMutableArray *array = [NSMutableArray array];
    for ( Client *socket in self.clientsArray) {
        if ([date timeIntervalSinceDate:socket.timeOfSocket] > 20 || !socket) {
            [socket.scocket disconnect];
            continue;
        }
        [array addObject:socket];
    }
    self.clientsArray = array;
}

-(void)serveGetMSG:(ServeMsgBlock)serveMsg{
    self.serveMsg = serveMsg;
}

@end
