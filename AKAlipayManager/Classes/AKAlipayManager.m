//
//  AKAlipayManager.m
//  Pods
//
//  Created by 李翔宇 on 2017/3/26.
//
//

#import "AKAlipayManager.h"
#import <AKAlipaySDK/AlipaySDK.h>
#import "AKAlipayManagerMacro.h"

const NSString * const AKAlipayManagerErrorCodeKey = @"code";
const NSString * const AKAlipayManagerErrorMessageKey = @"message";
const NSString * const AKAlipayManagerErrorDetailKey = @"detail";

static const NSString * const AKAlipayManagerMemoKey = @"memo";
static const NSString * const AKAlipayManagerResultCodeKey = @"resultStatus";
static const NSString * const AKAlipayManagerResultKey = @"result";
static const NSString * const AKAlipayManagerResultResponseKey = @"alipay_trade_app_pay_response";
static const NSString * const AKAlipayManagerResultResponseCodeKey = @"code";
static const NSString * const AKAlipayManagerResultResponseMessageKey = @"msg";

typedef NS_ENUM(NSUInteger, AKAlipayResultCode){
    AKAlipayResultCodeSuccess = 9000,//订单支付成功
    AKAlipayResultCodeWaiting = 8000,//正在处理中，支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
    AKAlipayResultCodeFailed = 4000,//订单支付失败
    AKAlipayResultCodeRepeated = 5000,//重复请求
    AKAlipayResultCodeCancelled = 6001,//用户中途取消
    AKAlipayResultCodeNetworkError = 6002,//网络连接出错
    AKAlipayResultCodeUnknown = 6004,//支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
    //其它，其它支付错误
};

typedef NS_ENUM(NSUInteger, AKAlipayResultResponseCode){
    AKAlipayResultResponseCodeSuccess = 10000,//接口调用成功
    AKAlipayResultResponseCodeServiceInvalid = 20000,//服务不可用
    AKAlipayResultResponseCodeAccessTokenError = 20001,//授权权限不足
    AKAlipayResultResponseCodeParamLack = 40001,//缺少必选参数
    AKAlipayResultResponseCodeParamError = 40002,//非法的参数
    AKAlipayResultResponseCodeBusinessError = 40004,//业务处理失败
    AKAlipayResultResponseCodePermissionError = 40006,//权限不足
};

@interface AKAlipayManager ()

@property (nonatomic, strong) AKAlipayManagerSuccess paySuccess;
@property (nonatomic, strong) AKAlipayManagerFailure payFailure;

@end

@implementation AKAlipayManager

+ (AKAlipayManager *)manager {
    static AKAlipayManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}

+ (id)alloc {
    return [self manager];
}

+ (id)allocWithZone:(NSZone * _Nullable)zone {
    return [self manager];
}

- (id)copy {
    return self;
}

- (id)copyWithZone:(NSZone * _Nullable)zone {
    return self;
}

#pragma mark- Public Method
+ (BOOL)handleOpenURL:(NSURL *)url {
    __block BOOL handle = NO;
    [[AlipaySDK defaultService] processOrderWithPaymentResult:url
                                              standbyCallback:^(NSDictionary *resultDic) {
                                                  handle = [self.manager handleResult:resultDic];
                                                  if(handle) {
                                                      self.manager.paySuccess = nil;
                                                      self.manager.payFailure = nil;
                                                  }
                                              }];
    return handle;
}

+ (void)pay:(NSString *)order
    success:(AKAlipayManagerSuccess)success
    failure:(AKAlipayManagerFailure)failure {
    AKAlipay_String_Nilable_Return(self.scheme, NO, {
        [self.manager failure:failure message:@"未设置scheme"];
    });
    
    AKAlipay_String_Nilable_Return(order, NO, {
        [self.manager failure:failure message:@"未设置order"];
    });
    
    self.manager.paySuccess = success;
    self.manager.payFailure = failure;
    
    [[AlipaySDK defaultService] payOrder:order
                              fromScheme:self.scheme
                                callback:^(NSDictionary *resultDic) {
                                    //wap支付结果回调
                                    [self.manager handleResult:resultDic];
                                    self.manager.paySuccess = nil;
                                    self.manager.payFailure = nil;
                                }];
}

#pragma mark- Private Method
- (BOOL)handleResult:(NSDictionary *)resultDic {
    /**
     Wiki:App支付同步通知参数说明
     https://doc.open.alipay.com/doc2/detail.htm?treeId=204&articleId=105302&docType=1
     */
    
    /**
     从文档中截取的样例
     {
        "memo" : "xxxxx",
        "result" : "{
            \"alipay_trade_app_pay_response\":{
                \"code\":\"10000\",
                \"msg\":\"Success\",
                \"app_id\":\"2014072300007148\",
                \"out_trade_no\":\"081622560194853\",
                \"trade_no\":\"2016081621001004400236957647\",
                \"total_amount\":\"0.01\",
                \"seller_id\":\"2088702849871851\",
                \"charset\":\"utf-8\",
                \"timestamp\":\"2016-10-11 17:43:36\"
            },
            \"sign\":\"NGfStJf3i3ooWBuCDIQSumOpaGBcQz+aoAqyGh3W6EqA/gmyPYwLJ2REFijY9XPTApI9YglZyMw+ZMhd3kb0mh4RAXMrb6mekX4Zu8Nf6geOwIa9kLOnw0IMCjxi4abDIfXhxrXyj********\",
            \"sign_type\":\"RSA2\"
        }",
        "resultStatus" : "9000"
     }
     */
    
    NSString *memo = resultDic[AKAlipayManagerResultCodeKey];
    AKAlipay_String_Nilable_Return(memo, NO, {
        [self failure:self.payFailure message:@"同步解析结果memo错误"];
    }, NO);
    
    NSString *resultCodeStr = resultDic[AKAlipayManagerResultCodeKey];
    AKAlipay_String_Nilable_Return(resultCodeStr, NO, {
        [self failure:self.payFailure message:@"同步解析结果resultCode错误"];
    }, NO);
    AKAlipayResultCode resultCode = [resultCodeStr integerValue];
    
    NSDictionary *result = resultDic[AKAlipayManagerResultKey];
    if(![result isKindOfClass:[NSDictionary class]]) {
        [self failure:self.payFailure message:@"同步解析结果result错误"];
        return NO;
    }
    
    NSDictionary *response = result[AKAlipayManagerResultResponseKey];
    if(![response isKindOfClass:[NSDictionary class]]) {
        [self failure:self.payFailure message:@"同步解析结果response错误"];
        return NO;
    }
    
    NSString *responseCodeStr = response[AKAlipayManagerResultResponseCodeKey];
    AKAlipay_String_Nilable_Return(responseCodeStr, NO, {
        [self failure:self.payFailure message:@"同步解析结果responseCode错误"];
    }, NO);
    AKAlipayResultResponseCode responseCode = [responseCodeStr integerValue];
    
    NSString *responseMessage = response[AKAlipayManagerResultResponseMessageKey];
    AKAlipay_String_Nilable_Return(responseMessage, NO, {
        [self failure:self.payFailure message:@"同步解析结果responseMessage错误"];
    }, NO);
    
    if(resultCode != AKAlipayResultCodeSuccess) {
        NSString *message = [self alertForResult:resultCode];
        [self failure:self.payFailure code:resultCode message:message detail:responseMessage];
        return NO;
    }
    
    if(responseCode != AKAlipayResultResponseCodeSuccess) {
        NSString *message = [self alertForResponse:responseCode];
        [self failure:self.payFailure code:responseCode message:message detail:responseMessage];
        return NO;
    }
    
    !self.paySuccess ? : self.paySuccess();
    return YES;
}

- (NSString *)alertForResult:(AKAlipayResultCode)code {
    NSString *alert = nil;
    switch (code) {
        case AKAlipayResultCodeWaiting: alert = @"正在处理中"; break;
        case AKAlipayResultCodeFailed: alert = @"订单支付失败"; break;
        case AKAlipayResultCodeRepeated: alert = @"重复请求"; break;
        case AKAlipayResultCodeCancelled: alert = @"用户中途取消"; break;
        case AKAlipayResultCodeNetworkError: alert = @"网络连接出错"; break;
        case AKAlipayResultCodeUnknown: alert = @"支付结果未知"; break;
        default: alert = @"其它支付错误"; break;
    }
    return alert;
}

- (NSString *)alertForResponse:(AKAlipayResultResponseCode)code {
    NSString *alert = nil;
    switch (code) {
        case AKAlipayResultResponseCodeSuccess: alert = @"接口调用成功"; break;
        case AKAlipayResultResponseCodeServiceInvalid: alert = @"服务不可用"; break;
        case AKAlipayResultResponseCodeAccessTokenError: alert = @"授权权限不足"; break;
        case AKAlipayResultResponseCodeParamLack: alert = @"缺少必选参数"; break;
        case AKAlipayResultResponseCodeParamError: alert = @"非法的参数"; break;
        case AKAlipayResultResponseCodeBusinessError: alert = @"业务处理失败"; break;
        case AKAlipayResultResponseCodePermissionError: alert = @"权限不足"; break;
        default: break;
    }
    return alert;
}

- (void)failure:(AKAlipayManagerFailure)failure message:(NSString *)message {
    if(AKAlipayManager.isDebug) {
        AKAlipayManagerLog(@"%@", message);
    }
    
    NSDictionary *userInfo = nil;
    if([message isKindOfClass:[NSString class]]
       && message.length) {
        userInfo = @{AKAlipayManagerErrorMessageKey : message};
    }
    
    NSError *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:0
                                     userInfo:userInfo];
    !failure ? : failure(error);
}

- (void)failure:(AKAlipayManagerFailure)failure code:(NSInteger)code message:(NSString *)message detail:(NSString *)detail {
    if(AKAlipayManager.isDebug) {
        AKAlipayManagerLog(@"%@", message);
        AKAlipayManagerLog(@"%@", detail);
    }
    
    NSMutableDictionary *userInfo = [@{AKAlipayManagerErrorCodeKey : @(code)} mutableCopy];
    if([message isKindOfClass:[NSString class]]
       && message.length) {
        userInfo[AKAlipayManagerErrorMessageKey] = message;
    }
    
    if([detail isKindOfClass:[NSString class]]
       && detail.length) {
        userInfo[AKAlipayManagerErrorDetailKey] = detail;
    }
    
    NSError *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:0
                                     userInfo:[userInfo copy]];
    !failure ? : failure(error);
}

@end
