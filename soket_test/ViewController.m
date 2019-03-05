//
//  ViewController.m
//  soket_test
//
//  Created by dongliang on 2019/3/4.
//  Copyright © 2019年 dl. All rights reserved.
//

#import "ViewController.h"
#import <GCDAsyncSocket.h>
#import "Serve.h"
#import "ClientA.h"
#import "ClientB.h"

@interface ViewController ()<UITextFieldDelegate,UITextViewDelegate>

@property (nonatomic, strong) UITextView *severTextView;
@property (nonatomic, strong) UITextView *clientATextView;
@property (nonatomic, strong) UITextView *clientBTextView;

@property (nonatomic, strong) UITextField *clientATf;
@property (nonatomic, strong) UITextField *clientBTf;

@property (nonatomic, strong) UIButton *clientASendButton;
@property (nonatomic, strong) UIButton *clientBSendButton;

@end

#define StatusViewHeight [[UIApplication sharedApplication] statusBarFrame].size.height
#define screen_w  [UIScreen mainScreen].bounds.size.width
#define screen_h  ([UIScreen mainScreen].bounds.size.height - StatusViewHeight)

#define textFiledHeight 30

@implementation ViewController

-(UITextView *)severTextView{
    if (!_severTextView) {
        _severTextView = [[UITextView alloc] init];
        _severTextView.backgroundColor = [UIColor orangeColor];
//        _severTextView.userInteractionEnabled = NO;
    }
    return _severTextView;
}

-(UITextView *)clientATextView{
    if (!_clientATextView) {
        _clientATextView = [[UITextView alloc] init];
        _clientATextView.backgroundColor = [UIColor whiteColor];
        _clientATextView.userInteractionEnabled = NO;
    }
    return _clientATextView;
}

-(UITextView *)clientBTextView{
    if (!_clientBTextView) {
        _clientBTextView = [[UITextView alloc] init];
        _clientBTextView.backgroundColor = [UIColor whiteColor];
        _clientBTextView.userInteractionEnabled = NO;
    }
    return _clientBTextView;
}

-(UITextField *)clientATf{
    if (!_clientATf) {
        _clientATf = [[UITextField alloc] init];
        _clientATf.backgroundColor = [UIColor lightGrayColor];
        _clientATf.placeholder = @"给B发消息";
        _clientATf.delegate = self;
    }
    return _clientATf;
}

-(UITextField *)clientBTf{
    if (!_clientBTf) {
        _clientBTf = [[UITextField alloc] init];
        _clientBTf.backgroundColor = [UIColor lightGrayColor];
        _clientBTf.placeholder = @"给A发消息";
        _clientBTf.delegate = self;
    }
    return _clientBTf;
}

-(UIButton *)clientASendButton{
    if (!_clientASendButton) {
        _clientASendButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _clientASendButton.backgroundColor = [UIColor blueColor];
        [_clientASendButton setTitle:@"发送" forState:UIControlStateNormal];
        [_clientASendButton addTarget:self action:@selector(sendMsgToB:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _clientASendButton;
}

-(UIButton *)clientBSendButton{
    if (!_clientBSendButton) {
        _clientBSendButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _clientBSendButton.backgroundColor = [UIColor blueColor];
        [_clientBSendButton setTitle:@"发送" forState:UIControlStateNormal];
        [_clientBSendButton addTarget:self action:@selector(sendMsgToA:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _clientBSendButton;
}

-(void)sendMsgToB:(UIButton *)sender{
    NSLog(@"发送消息给B");
    [_clientATf resignFirstResponder];
    NSData *data = [_clientATf.text dataUsingEncoding:NSUTF8StringEncoding];
    [[ClientA shareClinetA] sendData:data :@"txt" toClinet:@"CinentB"];
    _clientATf.text = @"";
}

-(void)sendMsgToA:(UIButton *)sender{
    NSLog(@"发送消息给A");
    [_clientBTf resignFirstResponder];
    NSData *data = [_clientBTf.text dataUsingEncoding:NSUTF8StringEncoding];
    [[ClientB shareClinetB] sendData:data :@"txt" toClinet:@"CinentA"];
    _clientBTf.text = @"";
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.clientATextView.frame = CGRectMake(0, StatusViewHeight, screen_w, screen_h / 3.0 - textFiledHeight);
    self.clientATf.frame = CGRectMake(0, screen_h / 3.0 - textFiledHeight, screen_w - 50, textFiledHeight);
    self.clientASendButton.frame = CGRectMake(screen_w - 40, screen_h / 3.0 - textFiledHeight, 40, textFiledHeight);
    self.severTextView.frame = CGRectMake(0, screen_h / 3.0 + 2, screen_w, screen_h / 3.0 - 2);
    self.clientBTextView.frame = CGRectMake(0, screen_h / 3.0 * 2, screen_w, screen_h / 3.0);
    self.clientBTf.frame = CGRectMake(0, screen_h - textFiledHeight, screen_w - 50, textFiledHeight);
    self.clientBSendButton.frame = CGRectMake(screen_w - 40, screen_h - textFiledHeight, 40, textFiledHeight);
    [self.view addSubview:self.clientATextView];
    [self.view addSubview:self.severTextView];
    [self.view addSubview:self.clientBTextView];
    [self.view addSubview:self.clientATf];
    [self.view addSubview:self.clientBTf];
    
    [self.view addSubview:self.clientASendButton];
    [self.view addSubview:self.clientBSendButton];
    
    __weak typeof(self) mySelf = self;
    [[Serve shareServe] openService];
    [[Serve shareServe] serveGetMSG:^(NSString * _Nonnull msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            mySelf.severTextView.text = [mySelf.severTextView.text stringByAppendingString:[NSString stringWithFormat:@"\n%@",msg]];
            mySelf.severTextView.layoutManager.allowsNonContiguousLayout = NO;
            [mySelf.severTextView scrollRectToVisible:CGRectMake(0, mySelf.severTextView.contentSize.height-15, mySelf.severTextView.contentSize.width, 10) animated:YES];
        });
    }];
    
    [[ClientA shareClinetA] connect];
    [[ClientA shareClinetA] clientAGetMsg:^(NSString * _Nonnull msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            mySelf.clientATextView.text = [mySelf.clientATextView.text stringByAppendingString:[NSString stringWithFormat:@"\n%@",msg]];
        });
    }];
    
    [[ClientA shareClinetA] sendMsgToB];
    
    [[ClientB shareClinetB] connect];
    [[ClientB shareClinetB] clientBGetMsg:^(NSString * _Nonnull msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            mySelf.clientBTextView.text = [mySelf.clientBTextView.text stringByAppendingString:[NSString stringWithFormat:@"\n%@",msg]];
        });
    }];
    [[ClientB shareClinetB] sendMsgToA];
}


@end
