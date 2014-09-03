#import <XCTest/XCTest.h>
#import <CocoaZ/TDTZCompressor.h>
#import <CocoaZ/TDTZDecompressor.h>
#import "TDTRandomInput.h"

static NSString *const TDTZlibTestsException = @"TDTZlibTestsException";

@interface TDTZDecompressorTests : XCTestCase

@property (nonatomic, strong) TDTZCompressor *compressor;
@property (nonatomic, strong) TDTZDecompressor *decompressor;

@end

@implementation TDTZDecompressorTests

@synthesize compressor = compressor_;
@synthesize decompressor = decompressor_;

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
  self.decompressor = [[TDTZDecompressor alloc] initWithCompressionFormat:TDTCompressionFormatGzip];
}

- (void)tearDown {
  self.compressor = nil;
  self.decompressor = nil;
}

# pragma mark - Decompression tests

- (void)testEmptyDataDecompression {
  NSData *inData = [NSData data];
  NSData *compressedData = [self gzipData:inData];
  NSData *decompressedData = [self.decompressor finishData:compressedData];
  XCTAssertTrue([decompressedData isEqualToData:inData], @"Input data not equal to output data");
}

- (void)testSmallDataDecompression {
  NSData *inData = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *compressedData = [self gzipData:inData];
  NSData *decompressedData = [self.decompressor finishData:compressedData];
  XCTAssertTrue([decompressedData isEqualToData:inData], @"Input data not equal to output data");
}

- (void)testLargeFileDecompression {
  NSData *inData = randomLargeData();
  NSData *compressedData = [self gzipData:inData];
  NSData *decompressedData = [self.decompressor finishData:compressedData];
  XCTAssertTrue([decompressedData isEqualToData:inData], @"Input data not equal to output data");
}

- (void)testLargeFile2Decompression {
  NSData *inData = randomLargeData();
  NSMutableData *compressedData = [NSMutableData data];
  [compressedData appendData:[self gzipData:inData]];
  [compressedData appendData:[self gzipData:nil]];
  NSData *decompressedData = [self.decompressor finishData:compressedData];
  XCTAssertTrue([decompressedData isEqualToData:inData], @"Input data not equal to output data");
}

- (void)testDecompressFile {
  NSData *inData = randomLargeData();
  NSData *compressedData = [self gzipData:inData];
  NSData *decompressedData = [self.decompressor finishData:compressedData];
  XCTAssertTrue([decompressedData isEqualToData:inData], @"Input data not equal to output data");
}

- (void)testDecompressFileError {
  NSString *path = randomLargeFilePath();
  // Modify path to a non-existent file
  path = [path stringByDeletingPathExtension];
  path = [path stringByAppendingPathExtension:@"dat2"];
  NSError *error;
  NSData *result = [self.decompressor decompressFile:path error:&error];
  XCTAssertNil(result, @"result should be nil");
  XCTAssertNotNil(error, @"error should be non-nil");
}

- (void)testMultiDecompress {
  NSData *inData = [@"foobarbazquux" dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData *decompressedData = [NSMutableData data];
  
  NSData *compressedData1 = [self.compressor compressData:[@"foobar" dataUsingEncoding:NSUTF8StringEncoding]];
  NSData *compressedData2 = [self.compressor compressData:[@"baz" dataUsingEncoding:NSUTF8StringEncoding]];
  NSData *compressedData3 = [self.compressor compressData:[@"quux" dataUsingEncoding:NSUTF8StringEncoding]];
  
  [decompressedData appendData:[self.decompressor decompressData:compressedData1]];
  [decompressedData appendData:[self.decompressor decompressData:compressedData2]];
  [decompressedData appendData:[self.decompressor decompressData:compressedData3]];
  [decompressedData appendData:[self.decompressor finishData:[self.compressor finishData:nil]]];
  
  XCTAssertTrue([decompressedData isEqualToData:inData], @"Input data not equal to output data");
}

- (void)testMultiDecompressFlush {
  NSData *inData = [@"foobarbazquux" dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData *decompressedData = [NSMutableData data];
  
  NSData *compressedData1 = [self.compressor compressData:[@"foobar" dataUsingEncoding:NSUTF8StringEncoding]];
  NSData *compressedData2 = [self.compressor compressData:[@"baz" dataUsingEncoding:NSUTF8StringEncoding]];
  NSData *compressedData3 = [self.compressor compressData:[@"quux" dataUsingEncoding:NSUTF8StringEncoding]];
  
  [decompressedData appendData:[self.decompressor flushData:compressedData1]];
  [decompressedData appendData:[self.decompressor flushData:compressedData2]];
  [decompressedData appendData:[self.decompressor flushData:compressedData3]];
  [decompressedData appendData:[self.decompressor finishData:[self.compressor finishData:nil]]];
  
  XCTAssertTrue([decompressedData isEqualToData:inData], @"Input data not equal to output data");
}

@end
