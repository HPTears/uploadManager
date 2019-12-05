//
//  XKUploadManager.h
//  XKSquare
//
//  Created by Jamesholy on 2018/8/7.
//  Copyright © 2018年 xk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface XKUploadManager : NSObject

/**
 单例

 @return 返回一个上传文件的单例对象
 */
+ (instancetype)shareManager;

/**
 获取token 本地没有或者过期请求服务器的

 @param success  成功回调
 @param failure 失败回调
 */
+ (void)getQNUploadToken:(void(^)(NSString *token))success Failure:(void (^)(NSString *errorStr))failure;

/**
  上传文本

 @param uploadString 需要上传的文本
 @param key 模块+业务名 自动拼接其他的
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadTextString:(NSString *)uploadString WithKey:(NSString *)key Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *error))failure;

/**
 上传文件
 
 @param filePath 要上传的文件路径
 @param key 模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadFileWithFilePath:(NSString *)filePath WithKey:(NSString *)key Progress:(void(^)(NSString *progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString * error))failure;


/**
 上传图片 单张

 @param image 上传的图片  图片内部会被压缩500kb以下 如果不想压缩或者自己想压成其他的 请使用uploadData
 @param key  模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadImage:(UIImage *)image withKey:(NSString *)key progress:(void(^)(CGFloat progress))progress success:(void(^)(NSString *key))success failure:(void (^)(NSString * error))failure;


/**
 多图上传

 @param imageArr 图片数组
 @param index 索引
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadImagesWithImagesArray:(NSArray <UIImage *>*)imageArr AtIndex:(NSInteger)index Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSArray *keyArray))success Failure:(void (^)(NSString *error))failure;


/**
 上传视频

 @param asset 相册资源文件
 @param key 模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadVideo:(PHAsset *)asset WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *error))failure;

/**
 上传视频 同时上传首帧图
 
 @param asset 相册资源文件
 @param image 首帧图 不传内部会根据视频自动获取
 @param key 模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadVideoBothFirstImg:(PHAsset *)asset FirstImg:(UIImage * _Nullable )image WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *videoKey,NSString *imgKey))success Failure:(void (^)(NSString *error))failure;

/**
 上传视频
 
 @param url 视频本地url
 @param key 模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadVideoWithUrl:(NSURL *)url WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *error))failure;

/**
 上传视频  同时上传首帧图
 
 @param url 视频本地url
 @param image 首帧图 不传内部会根据视频自动获取
 @param key 模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadVideoWithUrl:(NSURL *)url FirstImg:(UIImage * _Nullable )image WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *videoKey,NSString *imgKey))success Failure:(void (^)(NSString *error))failure;

/**
 上传data
 
 @param data data
 @param key 模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadData:(NSData *)data WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *error))failure;

@end
