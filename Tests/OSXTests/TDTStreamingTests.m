
#import <XCTest/XCTest.h>
#import <CocoaZ/TDTZCompressor.h>
#import <CocoaZ/TDTZDecompressor.h>

static NSString * const JARFileName = @"zlib-server";

typedef NS_ENUM(NSUInteger, TDTReductionScheme) {
  TDTReductionSchemeCompress,
  TDTReductionSchemeDecompress
};

@interface TDTStreamingTests : XCTestCase

@property NSTask *compressionServerTask;
@property NSString *port;

@end

@implementation TDTStreamingTests

+ (NSString *)port {
  static NSInteger Port;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Port = 8080;
  });
  __block NSString *newPort;
  @synchronized (self) {
    newPort = [NSString stringWithFormat:@"%@", @(Port)];
    Port++;
  }
  return newPort;
}

- (void)setUp {
  [super setUp];
  NSString *launchPath = [[NSBundle bundleForClass:[self class]] pathForResource:JARFileName ofType:@"jar"];
  self.port = [[self class] port];
  NSArray *arguments = @[@"-jar", launchPath, self.port];
  self.compressionServerTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/java" arguments:arguments];
  NSDate *date = [NSDate dateWithTimeIntervalSinceNow:5];
  [[NSRunLoop currentRunLoop] runUntilDate:date];
}

- (void)tearDown {
  [self.compressionServerTask terminate];
  [super tearDown];
}

- (NSURL *)endpointForScheme:(TDTReductionScheme)scheme {
  NSString *URLString = [NSString stringWithFormat:@"http://localhost:%@/", self.port];
  NSURL *URL = [NSURL URLWithString:URLString];
  switch (scheme) {
    case TDTReductionSchemeCompress:
      return [NSURL URLWithString:@"compress" relativeToURL:URL];
    case TDTReductionSchemeDecompress:
      return [NSURL URLWithString:@"decompress" relativeToURL:URL];
  }
}

- (NSURLRequest *)requestForScheme:(TDTReductionScheme)scheme
                                ID:(NSString *)ID
                              data:(NSString *)data {
  NSDictionary *headers = @{@"content-type": @"application/json"};
  NSDictionary *parameters = @{@"id": ID, @"data": data};

  NSError *error;
  NSData *postData = [NSJSONSerialization dataWithJSONObject:parameters
                                                     options:0
                                                       error:&error];
  XCTAssertNil(error);

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self endpointForScheme:scheme]
                                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                     timeoutInterval:5];
  [request setHTTPMethod:@"POST"];
  [request setAllHTTPHeaderFields:headers];
  [request setHTTPBody:postData];
  return request;
}

- (void)compressString:(NSString *)string
                    ID:(NSString *)ID
            completion:(void(^)(NSData *compressedData, NSError *error))completion {
  NSURLRequest *request = [self requestForScheme:TDTReductionSchemeCompress
                                              ID:ID
                                            data:string];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *dataTask
  = [session dataTaskWithRequest:request
               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                 if (error) {
                   completion(nil, error);
                 } else {
                   NSDictionary *res = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                   XCTAssertNil(error);
                   NSData *compressed = [[NSData alloc] initWithBase64EncodedData:res[@"data"] options:0];
                   XCTAssertNotNil(compressed);
                   completion(compressed, nil);
                 }
               }];
  [dataTask resume];
}

- (void)decompressString:(NSString *)string
                      ID:(NSString *)ID
              completion:(void(^)(NSString *decompressedData, NSError *error))completion {
  NSURLRequest *request = [self requestForScheme:TDTReductionSchemeDecompress
                                              ID:ID
                                            data:string];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *dataTask
  = [session dataTaskWithRequest:request
               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                 if (error) {
                   completion(nil, error);
                 } else {
                   NSDictionary *res = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                   XCTAssertNil(error);
                   NSString *decompressed = res[@"data"];
                   XCTAssertNotNil(decompressed);
                   completion(decompressed, nil);
                 }
               }];
  [dataTask resume];
}

- (NSString *)randomString {
  return [[NSUUID UUID] UUIDString];
}

- (void)testStreamDecompression {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Received compressed data"];

  NSString *string = [self randomString];
  [self compressString:string ID:[self randomString] completion:^(NSData *compressedData, NSError *error) {
    XCTAssertNil(error);
    TDTZDecompressor *decompressor = [[TDTZDecompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
    NSData *decompressed = [decompressor flushData:compressedData];
    NSString *orig = [[NSString alloc] initWithData:decompressed
                                           encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(string, orig);
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
    XCTAssertNil(error);
  }];
}

- (void)testStreamCompression {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Received decompressed data"];

  TDTZCompressor *compressor = [[TDTZCompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
  NSString *string = [self randomString];
  NSData *compressedData = [compressor flushData:[string dataUsingEncoding:NSUTF8StringEncoding]];
  NSString *base64EncodedData = [compressedData base64EncodedStringWithOptions:0];
  [self decompressString:base64EncodedData ID:[self randomString] completion:^(NSString *decompressedData, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(decompressedData, string);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
    XCTAssertNil(error);
  }];
}

- (void)testStreamCompressionForMultiplePackets {
  TDTZCompressor *compressor = [[TDTZCompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
  NSString *ID = [self randomString];
  for (NSUInteger i = 0; i < 1000; ++i) {
    NSLog(@"*** Started %@ %@", @(i), [NSDate date]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"Received decompressed data"];
    NSString *string = [self randomString];
    NSData *compressedData = [compressor flushData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *base64EncodedData = [compressedData base64EncodedStringWithOptions:0];
    [self decompressString:base64EncodedData ID:ID completion:^(NSString *decompressedData, NSError *error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(decompressedData, string);
      [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
      XCTAssertNil(error);
    }];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0.01];
    [[NSRunLoop currentRunLoop] runUntilDate:date];
    NSLog(@"*** Ended %@ %@", @(i), [NSDate date]);
  }
}

- (void)testStreamDecompressionForMultiplePackets {
  TDTZDecompressor *decompressor = [[TDTZDecompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
  NSString *ID = [self randomString];
  for (NSUInteger i = 0; i < 1000; ++i) {
    NSLog(@"*** Started %@ %@", @(i), [NSDate date]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"Received compressed data"];
    NSString *string = [self randomString];

    [self compressString:string ID:ID completion:^(NSData *compressedData, NSError *error) {
      XCTAssertNil(error);
      NSData *decompressed = [decompressor flushData:compressedData];
      NSString *orig = [[NSString alloc] initWithData:decompressed encoding:NSUTF8StringEncoding];
      XCTAssertEqualObjects(string, orig);
      [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
      XCTAssertNil(error);
    }];

    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0.01];
    [[NSRunLoop currentRunLoop] runUntilDate:date];
    NSLog(@"*** Ended %@ %@", @(i), [NSDate date]);
  }
}

@end
