
#import <XCTest/XCTest.h>
#import <CocoaZ/TDTZCompressor.h>
#import <CocoaZ/TDTZDecompressor.h>

static NSString * const JARFileName = @"zlib-1.0-SNAPSHOT-jar-with-dependencies";

@interface TDTStreamingTests : XCTestCase

@property NSTask *JARTask;

@end

@implementation TDTStreamingTests

- (void)setUp {
  [super setUp];
  NSString *launchPath = [[NSBundle bundleForClass:[self class]] pathForResource:JARFileName ofType:@"jar"];
  self.JARTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/java" arguments:@[@"-jar", launchPath]];
  NSDate *date = [NSDate dateWithTimeIntervalSinceNow:5];
  [[NSRunLoop currentRunLoop] runUntilDate:date];
}

- (void)tearDown {
  [self.JARTask terminate];
  [super tearDown];
}

- (NSURLRequest *)compressRequestWithID:(NSString *)ID data:(NSString *)data {
  NSDictionary *headers = @{@"content-type": @"application/json"};
  NSDictionary *parameters = @{@"id": ID, @"data": data};

  NSError *error;
  NSData *postData = [NSJSONSerialization dataWithJSONObject:parameters
                                                     options:0
                                                       error:&error];
  XCTAssertNil(error);

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:8080/compress"]
                                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                     timeoutInterval:5];
  [request setHTTPMethod:@"POST"];
  [request setAllHTTPHeaderFields:headers];
  [request setHTTPBody:postData];
  return request;
}

- (void)compressString:(NSString *)string completion:(void(^)(NSData *compressedData, NSError *error))completion {
  NSURLRequest *request = [self compressRequestWithID:@"test" data:string];

  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
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

- (void)testStreamCompression {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Received compressed data"];

  NSString *string = @"Test string data";
  [self compressString:string completion:^(NSData *compressedData, NSError *error) {
    XCTAssertNil(error);
    TDTZDecompressor *decompressor = [[TDTZDecompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
    NSData *decompressed = [decompressor flushData:compressedData];
    NSString *orig = [[NSString alloc] initWithData:decompressed encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(string, orig);
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
    NSLog(@"Expectation not fulfilled");
  }];
}

@end
