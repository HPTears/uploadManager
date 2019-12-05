//
//  XKUploadManager.m
//  XKSquare
//
//  Created by Jamesholy on 2018/8/7.
//  Copyright © 2018年 xk. All rights reserved.
//

#import "XKUploadManager.h"
#import <AFNetworking.h>
#import <QiniuSDK.h>
#import <QNResolver.h>
#import <QNDnsManager.h>
#import <QNNetworkInfo.h>
#import "HTTPClient.h"
#import "XKUserInfo.h"
#import "UIImage+Reduce.h"
#import <XKCategary/NSString+XKString.h>
#define CacheFile [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"QiNiuCacheFile"]

#define EXECUTE_BLOCK(A,...) if(A){A(__VA_ARGS__);}
#define XKWeakSelf(weakSelf)     __weak __typeof(&*self)    weakSelf  = self;

static NSString *QNUserDefaultTokenKey = @"QNUploadTokenCacheKey";
static NSString *QNTokenDicExpiryTimeKey = @"QNTokenDicExpiryTimeKey";
static NSString *QNTokenDicTokenKey = @"QNTokenDicTokenKey";

@interface XKUploadManager ()
@property (nonatomic, strong) QNUploadManager *upManager;
@property (nonatomic, strong) dispatch_queue_t queue;
/*上传回调*/
@property (nonatomic, copy) void(^singleSuccessBlock)(NSString *urlStr);
@property (nonatomic, copy) void(^singleFailureBlock)(NSString *errorStr);

@end

@implementation XKUploadManager

static XKUploadManager *_manager = nil;
+ (instancetype)shareManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[XKUploadManager alloc] init];
    });
    return _manager;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        self.queue = dispatch_queue_create("requestQNToken", DISPATCH_QUEUE_SERIAL);
        //        QNConfiguration *config =[QNConfiguration build:^(QNConfigurationBuilder *builder) {
        //            NSMutableArray *array = [[NSMutableArray alloc] init];
        //            [array addObject:[QNResolver systemResolver]];
        //            QNDnsManager *dns = [[QNDnsManager alloc] init:array networkInfo:[QNNetworkInfo normal]];
        //            builder.dns = dns;
        //            //是否选择  https  上传
        //            builder.useHttps = YES;
        //            //设置断点续传 将进度保存进文件
        //            NSError *error;
        //            builder.recorder =  [QNFileRecorder fileRecorderWithFolder:CacheFile error:&error];
        //        }];
        _upManager = [[QNUploadManager alloc] initWithConfiguration:nil];
    }
    return self;
}

#pragma mark - 获取token
+ (void)getQNUploadToken:(void(^)(NSString *token))success Failure:(void (^)(NSString *errorStr))failure {
    // 当存在循环请求token时  也保证token只会被请求一次 后续循环结果使用缓存
    dispatch_async([XKUploadManager shareManager].queue, ^{ // 异步串行执行
        __block NSString *QNToken = nil;
        __block NSString *QNError = nil;
        dispatch_semaphore_t signal = dispatch_semaphore_create(0);
        [self getQNTokenFromCacheOrNet:^(NSString *token) {  // 采用信号量将异步请求变同步操作（必须在异步线程 否则信号量会卡死主线程）
            QNToken = token;
            dispatch_semaphore_signal(signal);
        } Failure:^(NSString *error) {
            QNError = error;
            dispatch_semaphore_signal(signal);
        }];
        dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
        if (QNToken) {
            EXECUTE_BLOCK(success,QNToken);
        } else {
            EXECUTE_BLOCK(failure,QNError);
        }
    });
}

+ (void)getQNTokenFromCacheOrNet:(void (^)(NSString *token))success Failure:(void (^)(NSString *error))failure {
    // 为了不重复请求 将token存在本地
    NSString *token = nil;
    // 1.从本地取token
    NSDictionary *tokenDic = [[NSUserDefaults standardUserDefaults] objectForKey:QNUserDefaultTokenKey];
    if (tokenDic) {
        NSString *tmpToken = tokenDic[QNTokenDicTokenKey];
        NSString *tmpExpiryTime = tokenDic[QNTokenDicExpiryTimeKey];
        if (tmpToken.length != 0) {
            if (![self outTime:tmpExpiryTime]) { // 木有过期
                token = tmpToken;
                NSLog(@"用缓存的七牛token");
                EXECUTE_BLOCK(success,token);
                return;
            }
        }
    }
    
    [self requestQNUploadToken:^(NSDictionary *tokenInfo) {
        NSString *cacheToken = tokenInfo[@"upToken"];
        NSString *cacheTime = [NSString stringWithFormat:@"%@",tokenInfo[@"expiryTime"]];
        if (cacheToken.length != 0) {
            // 缓存本地
            NSMutableDictionary *tokenDic = @{}.mutableCopy;
            tokenDic[QNTokenDicTokenKey] = cacheToken;
            tokenDic[QNTokenDicExpiryTimeKey] = cacheTime;
            [[NSUserDefaults standardUserDefaults] setObject:tokenDic forKey:QNUserDefaultTokenKey];
            NSLog(@"用请求的七牛新的token");
            EXECUTE_BLOCK(success,cacheToken);
        } else {
            EXECUTE_BLOCK(failure,@"文件上传异常");
        }
    } Failure:^(NSString *error) {
        EXECUTE_BLOCK(failure,error);
    }];
}

// 请求token
+ (void)requestQNUploadToken:(void (^)(NSDictionary *tokenInfo))success Failure:(void (^)(NSString *error))failure {
    
    [HTTPClient getEncryptRequestWithURLString:@"sys/ua/qosstoken/1.0" timeoutInterval:20 parameters:nil success:^(id responseObject) {
        NSDictionary *params = [responseObject xk_jsonToDic];
        success(params);
    } failure:^(XKHttpErrror *error) {
        failure(error.message);
    }];
}

+ (BOOL)outTime:(NSString *)tmpExpiryTime {
    long expiryTime = [tmpExpiryTime longLongValue];
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    if (expiryTime - currentTime < 300) { // 还有5分钟就过期了 重新搞
        return YES;
    }
    return NO;
}

#pragma mark - 拼接key
- (NSString *)buildKeyWithKey:(NSString *)key {
    return [NSString stringWithFormat:@"%@_%@_%d_%@",[XKUserInfo getCurrentUserId]?:@"userId",[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]] ,arc4random()%100000,key?:@"module"];
}

#pragma mark - 请求相关
- (void)qiniuUpload:(NSString *)token data:(NSData *)data key:(NSString *)key progress:(void(^)(CGFloat progress))progress complete:(void(^)(NSString *error, NSString * key, NSString * hash))result  {
    QNUploadOption *uploadOption;
    if (progress) {
        uploadOption = [[QNUploadOption alloc] initWithMime:@"" progressHandler:^(NSString *key, float percent) {
            NSLog(@"上传进度%.2f",percent);
            //            NSString *per = [NSString stringWithFormat:@"上传进度%.2f",percent];
            progress(percent);
        } params:nil checkCrc:NO cancellationSignal:nil];
    }
    NSString *specialKey = [self buildKeyWithKey:key];
    [self.upManager putData:data key:specialKey token:token
                   complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
                       NSLog(@"%@", info);
                       NSLog(@"%@", resp);
                       if (!info.error) {
                           NSString *backKey = [resp objectForKey:@"key"];
                           NSString *hash = [resp objectForKey:@"hash"];
                           result(nil,backKey,hash);
                       } else {
                           result(info.error.localizedDescription,nil,nil);
                       }
                   } option:uploadOption];
    [self.upManager putPHAsset:nil key:nil token:nil complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        //
    } option:nil];
}

#pragma mark - 上传文本
- (void)uploadTextString:(NSString *)uploadString WithKey:(NSString *)key Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *data))failure {
    __weak typeof(self) weakSelf = self;
    NSData *uploadData = [uploadString dataUsingEncoding:NSUTF8StringEncoding];
    [XKUploadManager getQNUploadToken:^(NSString *token) {
        [weakSelf qiniuUpload:token data:uploadData key:key progress:nil complete:^(NSString *error, NSString *key, NSString *hash) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    failure(error);
                } else {
                    success(key,hash);
                }
            });
            
        }];
    } Failure:^(NSString *errorStr) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(errorStr);
        });
    }];
}

#pragma mark - 上传文件
- (void)uploadFileWithFilePath:(NSString *)filePath WithKey:(NSString *)key Progress:(void(^)(NSString *progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *data))failure {
    XKWeakSelf(ws);
    QNUploadOption *uploadOption = [[QNUploadOption alloc] initWithMime:@"" progressHandler:^(NSString *key, float percent) {
        NSLog(@"上传进度%.2f",percent);
        NSString *per = [NSString stringWithFormat:@"上传进度%.2f",percent];
        progress(per);
    } params:nil checkCrc:NO cancellationSignal:nil];
    
    [XKUploadManager getQNUploadToken:^(NSString *token) {
        [ws.upManager putFile:filePath key:[self buildKeyWithKey:key] token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(info.ok) {
                    NSString *backKey = [resp objectForKey:@"key"];
                    NSString *hash = [resp objectForKey:@"hash"];
                    success(backKey,hash);
                } else {
                    //如果失败，这里可以把info信息上报自己的服务器，便于后面分析上传错误原因
                    failure(@"上传失败");
                }
            });
        } option:uploadOption];
    } Failure:^(NSString *errorStr) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(errorStr);
        });
    }];
}

#pragma mark- 上传图片 单
- (void)uploadImage:(UIImage *)image withKey:(NSString *)key progress:(void(^)(CGFloat progress))progress success:(void(^)(NSString *url))success failure:(void (^)(NSString *data))failure {
    [XKUploadManager getQNUploadToken:^(NSString *token) {
        [self uploadImage:image withKey:key token:token progress:progress success:^(NSString *url) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(url);
            });
        } failure:^(id data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(data);
            });
        }];
    } Failure:^(NSString *errorStr) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(errorStr);
        });
    }];
}

- (void)uploadImage:(UIImage *)image withKey:(NSString *)key token:(NSString *)token progress:(void(^)(CGFloat progress))progress success:(void(^)(NSString *url))success failure:(void (^)(id data))failure {
    XKWeakSelf(ws);
    NSData *imageData = [image imageCompressForSpecifyKB:500];
    
    [ws qiniuUpload:token data:imageData key:key progress:progress complete:^(NSString *error, NSString *key, NSString *hash) {
        if (error) {
            failure(error);
        } else {
            success(key);
        }
    }];
}

#pragma mark-多图上传
- (void)uploadImagesWithImagesArray:(NSArray <UIImage *>*)imageArr AtIndex:(NSInteger)index Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSArray *keyArray))success Failure:(void (^)(NSString *error))failure{
    XKWeakSelf(ws);
    NSMutableArray *urlArr = [NSMutableArray array];
    __block CGFloat totalProgress = 0;
    __block CGFloat partProgress = 1.0f/imageArr.count;
    __block NSInteger currentIndex = 0;
    [XKUploadManager getQNUploadToken:^(NSString *token) {
        ws.singleSuccessBlock = ^(NSString *urlStr) {
            [urlArr addObject:urlStr];
            totalProgress += partProgress;
            progress(totalProgress);
            currentIndex ++;
            //如果保存的url个数和上传的图片个数相同  表示上传完成
            if(urlArr.count == imageArr.count) {
                success([urlArr copy]);
            } else {
                UIImage *image = imageArr[currentIndex];
                [ws uploadImage:image withKey:nil token:token progress:progress success:ws.singleSuccessBlock failure:ws.singleFailureBlock];
            }
        };
        
        ws.singleFailureBlock = ^(NSString *errorStr) {
            NSLog(@"第%ld张上传失败",(long)currentIndex);
            NSString *error = [NSString stringWithFormat:@"第%ld张上传失败",(long)currentIndex];
            failure(error);
        };
        
        [ws uploadImage:imageArr[0] withKey:nil token:token progress:progress success:ws.singleSuccessBlock failure:ws.singleFailureBlock];
    } Failure:^(NSString *errorStr) {
        failure(errorStr);
    }];
    
}

#pragma mark - 上传视频 phaseet
- (void)uploadVideo:(PHAsset *)asset WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *error))failure {
    XKWeakSelf(ws);
    [self getVideoFromPHAsset:asset complete:^(NSString *error, AVURLAsset *asset) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        } else {
            [ws uploadVideoWithUrl:asset.URL WithKey:key Progress:nil Success:success Failure:failure];
        }
    }];
}

- (void)uploadVideoBothFirstImg:(PHAsset *)asset FirstImg:(UIImage * _Nullable)image WithKey:(NSString *)key Progress:(void (^)(CGFloat))progress Success:(void (^)(NSString *, NSString *))success Failure:(void (^)(NSString *))failure {
    
    XKWeakSelf(ws);
    [self getVideoFromPHAsset:asset complete:^(NSString *error, AVURLAsset *asset) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        } else {
            [ws uploadVideoWithUrl:asset.URL FirstImg:image WithKey:key Progress:progress Success:success Failure:failure];
        }
    }];
}

/**
 上传视频
 
 @param url 视频url
 @param key 模块+业务名 自动拼接其他的
 @param progress 进度
 @param success 成功回调
 @param failure 失败回调
 */
- (void)uploadVideoWithUrl:(NSURL *)url WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *error))failure {
    __weak typeof(self) weakSelf = self;
    [XKUploadManager getQNUploadToken:^(NSString *token) {
        [self compressVideoToMp4 :url complete:^(NSString *error, id data) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(error);
                });
            } else {
                [weakSelf qiniuUpload:token data:data key:key progress:progress complete:^(NSString *error, NSString *key, NSString *hash) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (error) {
                            failure(error);
                        } else {
                            success(key,hash);
                        }
                    });
                }];
            }
        }];
    } Failure:^(NSString *errorStr) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(errorStr);
        });
    }];
}

- (void)uploadVideoWithUrl:(NSURL *)url FirstImg:(UIImage * _Nullable )image WithKey:(NSString *)key  Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *videoKey,NSString *imgKey))success Failure:(void (^)(NSString *error))failure {
    if (image == nil) { // 要获取
        image = [self getFirstImage:[AVURLAsset assetWithURL:url]];
        if (image == nil) {
            EXECUTE_BLOCK(failure,@"处理视频出现异常");
            return;
        }
    }
    [self uploadImage:image withKey:key progress:nil success:^(NSString *imgKey) {
        [self uploadVideoWithUrl:url WithKey:key Progress:progress Success:^(NSString *videoKey, NSString *hash) {
            EXECUTE_BLOCK(success,videoKey,imgKey);
        } Failure:^(NSString *error) {
            EXECUTE_BLOCK(failure,@"上传视频失败");
        }];
    } failure:^(NSString *error) {
        EXECUTE_BLOCK(failure,@"上传视频失败");
    }];
}

#pragma mark - 上传data
- (void)uploadData:(NSData *)data WithKey:(NSString *)key Progress:(void(^)(CGFloat progress))progress Success:(void(^)(NSString *key, NSString *hash))success Failure:(void (^)(NSString *error))failure {
    __weak typeof(self) weakSelf = self;
    [XKUploadManager getQNUploadToken:^(NSString *token) {
        [weakSelf qiniuUpload:token data:data key:key progress:progress complete:^(NSString *error, NSString *key, NSString *hash) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    failure(error);
                } else {
                    success(key,hash);
                }
            });
        }];
    } Failure:^(NSString *errorStr) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(errorStr);
        });
    }];
}

// 获取视频资源
- (void)getVideoFromPHAsset:(PHAsset *)phAsset complete:(void(^)(NSString *error,AVURLAsset *asset))result {
    
    if (phAsset.mediaType == PHAssetMediaTypeVideo || phAsset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionOriginal;
        options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
        options.networkAccessAllowed = YES;
        
        PHImageManager *manager = [PHImageManager defaultManager];
        [manager requestAVAssetForVideo:phAsset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            AVURLAsset *urlAsset = (AVURLAsset *)asset;
            result(nil,urlAsset);
        }];
    } else {
        result(@"未知错误", nil);
    }
}

// 压缩视频并转成MP4
- (void)compressVideoToMp4:(NSURL *)url complete:(void(^)(NSString *error, id data))result {
    //  让我们先判断是不是mp4视频，如果是mp4视频 那就不压缩了 因为在项目中在拍摄或者相册选择中mp4已经是转过的了
    if ([url.absoluteString.lowercaseString hasSuffix:@".mp4"]) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        result(nil,data);
        return;
    }
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:url];
    
    //保存至沙盒路径
    NSString *videoPath = [[XKUploadManager getRandomPath] stringByAppendingString:@".mp4"];
    
    //转码配置
    AVAssetExportSession *exportSession= [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetMediumQuality];
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.outputURL = [NSURL fileURLWithPath:videoPath];
    exportSession.outputFileType = AVFileTypeMPEG4;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        int exportStatus = exportSession.status;
        switch (exportStatus)
        {
            case AVAssetExportSessionStatusFailed:
            {
                NSError *exportError = exportSession.error;
                result(exportError.localizedDescription,nil);
                break;
            }
            case AVAssetExportSessionStatusCompleted:
            {
                NSData *data = [NSData dataWithContentsOfFile:videoPath];
                [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
                result(nil,data);
                break;
            }
            default:{
                result(@"未知错误，请重试",nil);
            }
        }
    }];
}

#pragma mark - 获取首帧图
- (UIImage *)getFirstImage:(AVURLAsset *)asset {
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = 0;
    NSError *thumbnailImageGenerationError = nil;
    
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 15) actualTime:NULL error:&thumbnailImageGenerationError];
    
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
    
    //NSData *imageData = UIImagePNGRepresentation(thumbnailImage);
    
    CGImageRelease(thumbnailImageRef);
    
    return thumbnailImage;
}


+ (NSString *)getTmpCachePath {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"xkMediaCache"]; // 路径
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) { // 文件夹不存在
        BOOL bo = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (!bo) {
            NSLog(@"%@文件夹创建失败",path);
        }
    }
    return path;
}

+ (NSString *)getRandomAfter {
    return [NSString stringWithFormat:@"%@_%d",[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]] ,arc4random()%100000];
}

+ (NSString *)getRandomPath {
    return [[XKUploadManager getTmpCachePath] stringByAppendingPathComponent:[XKUploadManager getRandomAfter]];
}

@end
