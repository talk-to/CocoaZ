//
//  TDTRandomInput.m
//  CocoaZTests
//
//  Created by Chaitanya Gupta on 03/09/14.
//  Copyright (c) 2014 Talk to. All rights reserved.
//

#import "TDTRandomInput.h"

static const NSUInteger LargeFileLength = 65536;

void *randomBufferOfLength(NSUInteger length) {
  size_t slength = (size_t)length;
  void *buffer = malloc(slength);
  arc4random_buf(buffer, slength);
  return buffer;
}

NSURL *randomLargeFileURL() {
  static NSURL *URL = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *temporaryDirectory = NSTemporaryDirectory();
    NSString *template = [temporaryDirectory stringByAppendingPathComponent:@"largefileXXXX"];
    NSUInteger length = [template lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    char *templateCString = malloc(sizeof(char) * length);
    if (![template getCString:templateCString maxLength:length encoding:NSUTF8StringEncoding]) {
      NSLog(@"Couldn't get C string");
      return;
    }
    int fd = mkstemp(templateCString);
    if (fd == -1) {
      NSLog(@"Couldn't create fd for large random file: %s", strerror(errno));
      return;
    }
    void *buffer = randomBufferOfLength(LargeFileLength);
    ssize_t bytesWritten = write(fd, buffer, (size_t)LargeFileLength);
    if (bytesWritten == -1) {
      NSLog(@"Couldn't write random data to file: %s", strerror(errno));
      return;
    }
    close(fd);
    NSLog(@"Created random large file at: %s", templateCString);
    URL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:templateCString]];
  });
  return URL;
}

NSString *randomLargeFilePath() {
  return [randomLargeFileURL() path];
}

NSData *randomLargeData() {
  static NSData *data = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    void *buffer = randomBufferOfLength(LargeFileLength);
    data = [NSData dataWithBytes:buffer length:LargeFileLength];
  });
  return data;
}

