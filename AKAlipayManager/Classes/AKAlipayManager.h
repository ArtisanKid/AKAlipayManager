//
//  AKAlipayManager.h
//  Pods
//
//  Created by 李翔宇 on 2017/3/26.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSString * const AKAlipayManagerErrorCodeKey;
extern const NSString * const AKAlipayManagerErrorMessageKey;
extern const NSString * const AKAlipayManagerErrorDetailKey;

typedef void (^AKAlipayManagerSuccess)();
typedef void (^AKAlipayManagerFailure)(NSError *error);

/**
 SDK文档：https://doc.open.alipay.com/docs/doc.htm?spm=a219a.7629140.0.0.WJYQnv&treeId=204&articleId=105295&docType=1
 */

@interface AKAlipayManager : NSObject

/**
 标准单例模式
 
 @return AKQQManager
 */
+ (AKAlipayManager *)manager;

@property (class, nonatomic, assign, getter=isDebug) BOOL debug;
@property (class, nonatomic, strong) NSString *scheme;

//处理从Application回调方法获取的URL
+ (BOOL)handleOpenURL:(NSURL *)url;

/**
 支付
 
 @param orderID 订单信息
 @param success 成功的Block
 @param failure 失败的Block
 */
+ (void)pay:(NSString *)order
    success:(AKAlipayManagerSuccess _Nullable)success
    failure:(AKAlipayManagerFailure _Nullable)failure;

@end

NS_ASSUME_NONNULL_END
