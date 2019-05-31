//
//  CLDownLoadUtil.h
//  VideoHeadline
//
//  Created by 谭春林 on 2019/5/9.
//  Copyright © 2019 IgCoding. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface CLDownLoadUtil : NSObject

/**
 根据URL下载文件

 @param url 文件链接
 @param progress 进度
 @param completed 完成下载回调
 @param failed 失败下载回调
 */
-(void)downloadWithURL:(NSURL *)url progress:(void(^)(CGFloat progress))progress completed:(void(^)(NSString *filePath))completed failed:(void(^)(NSString *msg))failed;

/**
  暂停
 */
-(void)pasue;
@end

NS_ASSUME_NONNULL_END
