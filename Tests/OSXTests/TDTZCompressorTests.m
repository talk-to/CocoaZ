#import <XCTest/XCTest.h>
#import <CocoaZ/TDTZCompressor.h>
#import "TDTRandomInput.h"

static NSString *const TDTZlibTestsException = @"TDTZlibTestsException";

@interface TDTZCompressorTests : XCTestCase

@property (nonatomic, strong) TDTZCompressor *compressor;

@end

@implementation TDTZCompressorTests

@synthesize compressor = compressor_;

// Runs the 'gunzip' utility and returns data from its standard output
- (NSData *)gunzipData:(NSData *)data {
  NSFileManager *dfm = [NSFileManager defaultManager];
  NSString *tmpDir = NSTemporaryDirectory();
  NSString *tmpPath = [tmpDir stringByAppendingPathComponent:@"compressedData.gz"];
  NSString *tmpOutPath = [tmpDir stringByAppendingPathComponent:@"compressedData"];
  if (![dfm createFileAtPath:tmpPath contents:data attributes:nil]) {
    NSLog(@"Couldn't create file at path: %@", tmpPath);
    return nil;
  }
  [dfm removeItemAtPath:tmpOutPath error:NULL];
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:@"/usr/bin/gunzip"];
  [task setArguments:[NSArray arrayWithObjects:tmpPath, nil]];
  [task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
  [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
  [task launch];
  [task waitUntilExit];
  int status = [task terminationStatus];
  if (status == 0) {
    return [NSData dataWithContentsOfFile:tmpOutPath];
  } else {
    @throw [NSException exceptionWithName:TDTZlibTestsException reason:@"gunzip didn't return successfully" userInfo:nil];
  }
}

- (NSData *)gzipData:(NSData *)data {
  NSFileManager *dfm = [NSFileManager defaultManager];
  NSString *tmpDir = NSTemporaryDirectory();
  NSString *tmpPath = [tmpDir stringByAppendingPathComponent:@"data"];
  NSString *tmpOutPath = [tmpDir stringByAppendingPathComponent:@"data.gz"];
  if (![dfm createFileAtPath:tmpPath contents:data attributes:nil]) {
    NSLog(@"Couldn't create file at path: %@", tmpPath);
    return nil;
  }
  [dfm removeItemAtPath:tmpOutPath error:NULL];
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:@"/usr/bin/gzip"];
  [task setArguments:[NSArray arrayWithObjects:tmpPath, nil]];
  [task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
  [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
  [task launch];
  [task waitUntilExit];
  int status = [task terminationStatus];
  if (status == 0) {
    return [NSData dataWithContentsOfFile:tmpOutPath];
  } else {
    @throw [NSException exceptionWithName:TDTZlibTestsException reason:@"gzip didn't return successfully" userInfo:nil];
  }
}

- (void)setUp {
  self.compressor = [[TDTZCompressor alloc] initWithCompressionFormat:TDTCompressionFormatGzip];
}

- (void)tearDown {
  self.compressor = nil;
}

#pragma mark - Compression tests

- (void)testEmptyData {
  NSData *inData = [NSData data];
  NSData *compressedData = [self.compressor finishData:inData];
  NSData *gunzipData = [self gunzipData:compressedData];
  XCTAssertTrue([gunzipData isEqualToData:inData], @"Input data not equal to gunzip data");
}

- (void)testSmallData {
  NSData *inData = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *compressedData = [self.compressor finishData:inData];
  NSData *gunzipData = [self gunzipData:compressedData];
  XCTAssertTrue([gunzipData isEqualToData:inData], @"Input data not equal to gunzip data");
}

- (void)testLargeFile {
  NSData *inData = randomLargeData();
  NSData *compressedData = [self.compressor finishData:inData];
  NSData *gunzipData = [self gunzipData:compressedData];
  XCTAssertTrue([gunzipData isEqualToData:inData], @"Input data not equal to gunzip data");
}

- (void)testLargeFile2 {
  NSData *inData = randomLargeData();
  NSMutableData *compressedData = [NSMutableData data];
  [compressedData appendData:[self.compressor compressData:inData]];
  [compressedData appendData:[self.compressor finishData:nil]];
  NSData *gunzipData = [self gunzipData:compressedData];
  XCTAssertTrue([gunzipData isEqualToData:inData], @"Input data not equal to gunzip data");
}

- (void)testCompressFile {
  NSString *path = randomLargeFilePath();
  NSData *inData = [NSData dataWithContentsOfFile:path];
  NSData *compressedData = [self.compressor compressFile:path error:NULL];
  NSData *gunzipData = [self gunzipData:compressedData];
  XCTAssertTrue([gunzipData isEqualToData:inData], @"Input data not equal to gunzip data");
}

- (void)testCompressFileError {
  NSString *path = randomLargeFilePath();
  // Modify path to a non-existent file
  path = [path stringByDeletingPathExtension];
  path = [path stringByAppendingPathExtension:@"dat2"];
  NSError *error;
  NSData *result = [self.compressor compressFile:path error:&error];
  XCTAssertNil(result, @"result should be nil");
  XCTAssertNotNil(error, @"error should be non-nil");
}

- (void)testMultiCompress {
  NSMutableData *compressedData = [NSMutableData data];
  [compressedData appendData:[self.compressor compressData:[@"foobar" dataUsingEncoding:NSUTF8StringEncoding]]];
  [compressedData appendData:[self.compressor compressData:[@"baz" dataUsingEncoding:NSUTF8StringEncoding]]];
  [compressedData appendData:[self.compressor compressData:[@"quux" dataUsingEncoding:NSUTF8StringEncoding]]];
  [compressedData appendData:[self.compressor finishData:nil]];
  NSData *inData = [@"foobarbazquux" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *gunzipData = [self gunzipData:compressedData];
  XCTAssertTrue([gunzipData isEqualToData:inData], @"Input data not equal to gunzip data");
}

- (void)testMultiCompressFlush {
  NSMutableData *compressedData = [NSMutableData data];
  [compressedData appendData:[self.compressor flushData:[@"foobar" dataUsingEncoding:NSUTF8StringEncoding]]];
  [compressedData appendData:[self.compressor flushData:[@"baz" dataUsingEncoding:NSUTF8StringEncoding]]];
  [compressedData appendData:[self.compressor flushData:[@"quux" dataUsingEncoding:NSUTF8StringEncoding]]];
  [compressedData appendData:[self.compressor finishData:nil]];
  NSData *inData = [@"foobarbazquux" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *gunzipData = [self gunzipData:compressedData];
  XCTAssertTrue([gunzipData isEqualToData:inData], @"Input data not equal to gunzip data");
}

@end
