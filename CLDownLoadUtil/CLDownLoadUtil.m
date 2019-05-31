//
//  CLDownLoadUtil.m
//  VideoHeadline
//
//  Created by 谭春林 on 2019/5/9.
//  Copyright © 2019 IgCoding. All rights reserved.
//

#import "CLDownLoadUtil.h"
@interface CLDownLoadUtil()<NSURLSessionDataDelegate>
@property (nonatomic ,strong) NSURLSession *downloadSession;
@property (nonatomic ,strong) NSURLSessionDataTask *downloadTask;
@property (nonatomic ,assign) long long expectedContentLength;//服务器文件长度
@property (nonatomic ,strong) NSString *fileName;//服务器文件名称
@property (nonatomic ,strong) NSString *filePath;//本地路径
@property (nonatomic ,strong) NSOutputStream *outputStream;//文件写入
@property (nonatomic ,assign) long long totalLength;//下载文件总长度
@property (nonatomic ,copy) void(^progress)(CGFloat progress);//进度回调
@property (nonatomic ,copy) void(^completed)(NSString *filePath);//下载完成回调
@property (nonatomic ,copy) void(^failed)(NSString *msg);//失败回调

@end
@implementation CLDownLoadUtil
- (NSURLSession *)downloadSession{
    if (_downloadSession == nil) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 20.0f;
        _downloadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return _downloadSession;
}
- (NSString *)filePath{
    if (!_filePath) {
        _filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:self.fileName];
        NSLog(@"文件路径:%@",_filePath);
    }
    return _filePath;
}
- (NSOutputStream *)outputStream{
    if (!_outputStream) {
        _outputStream = [[NSOutputStream alloc]initToFileAtPath:self.filePath append:YES];
        [_outputStream open];
    }
    return _outputStream;
}
-(void)downloadWithURL:(NSURL *)url progress:(void (^)(CGFloat))progress completed:(void (^)(NSString * _Nonnull))completed failed:(void (^)(NSString * _Nonnull))failed{
    //保存block
    self.progress = progress;
    self.completed = completed;
    self.failed = failed;
    //1.去服务器获取文件基本信息，文件长度，文件名称等
    [self checkURLInfo:url];
    //2.检查本地是否存在此文件并和服务文件大小进行比较 a.如果本地文件大小和服务器文件大小一致则无需下载文件，b.如果本地文件大小小于服务器大小则继续下载。c.如果本地文件大于服务文件则删除并重新下载。
   BOOL needDownload =  [self checkLocalFile];
    //3.下载服务器文件
    if (needDownload) {
        [self downloadFileWithURL:url];
    }
}
- (void)pasue{
    [self.downloadTask cancel];
    [self.downloadSession finishTasksAndInvalidate];
    self.downloadSession = nil;
    [self.outputStream close];
    self.outputStream = nil;
    
}
/**
 检查服务器文件信息

 @param url 文件链接
 */
-(void)checkURLInfo:(NSURL *)url{
    //创建信号量
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:(NSURLRequestUseProtocolCachePolicy) timeoutInterval:8.0];
    request.HTTPMethod = @"HEAD";
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        self.expectedContentLength = response.expectedContentLength;
        self.fileName = response.suggestedFilename;
        if (response.expectedContentLength == -1) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            long long length = [httpResponse.allHeaderFields[@"Content-Length"] longLongValue];
            self.expectedContentLength = length;
        }
        NSLog(@"文件长度%@",[NSString stringWithFormat:@"%lld",self.expectedContentLength]);
        NSLog(@"文件名称:%@",response.suggestedFilename);
        //解除锁定
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    //锁住进程
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

/**
 检查本地文件
 */
-(BOOL)checkLocalFile{
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
        NSDictionary *dic = [[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:nil];
        long long fileSize = [dic[NSFileSize] longLongValue];
        if (fileSize == self.expectedContentLength && fileSize != 0) {//文件已存在
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.completed) {
                    self.completed(self.filePath);
                }
            });
            
            return NO;
        }else if (fileSize > self.expectedContentLength){//文件有问题
            self.totalLength = 0;
            [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
            return YES;
        }
        self.totalLength = fileSize;
        NSLog(@"%@",dic);
        return YES;
    }else{
        
        return YES;
    }
   
}
-(void)downloadFileWithURL:(NSURL *)url{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSString *range = [NSString stringWithFormat:@"bytes=%lld-",self.totalLength];
    [request setValue:range forHTTPHeaderField:@"Range"];
    self.downloadTask = [self.downloadSession dataTaskWithRequest:request];
    [self.downloadTask resume];
}
#pragma mark -- NSURLSessionDownloadDelegate -- 代理方法
/*收到服务器响应*/
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    completionHandler(NSURLSessionResponseAllow);
    NSLog(@"收到响应");
}
/*收到下载数据*/
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    [self.outputStream write:data.bytes maxLength:data.length];
    self.totalLength += data.length;
    float progress = (float) self.totalLength / self.expectedContentLength;
    if (self.progress) {
        self.progress(progress);
    }
    NSLog(@"下载进度:%.2f",progress);
}
/*下载出错*/
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    if (!error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completed) {
                self.completed(self.filePath);
            }
        });
       
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.failed) {
                self.failed([error localizedDescription]);
            }
        });
       
    }
    NSLog(@"下载完成");
    [self.outputStream close];
    self.outputStream = nil;
    [self.downloadSession finishTasksAndInvalidate];
    self.downloadSession = nil;
    self.downloadTask = nil;
}
-(void)dealloc{
    NSLog(@"%@走了",NSStringFromClass([self class]));
}
@end
