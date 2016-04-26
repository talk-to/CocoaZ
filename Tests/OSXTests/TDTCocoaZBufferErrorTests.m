#import <XCTest/XCTest.h>
#import <CocoaZ/TDTZDecompressor.h>
#import <CocoaZ/TDTZCompressor.h>
#import "TDTRandomInput.h"

/**
 These tests were to try to and reproduce a Z_BUF_ERROR by
 setting up the scenarios outlined in the FAQ [1].

   5. deflate() or inflate() returns Z_BUF_ERROR.

   "Before making the call, make sure that avail_in and avail_out are not zero."

   "When setting the parameter flush equal to Z_FINISH,
    also make sure that avail_out is big enough to allow processing
    all pending input."

 Only testCompressFlushWithoutData triggered the Z_BUF_ERROR. The
 rest are being retained for future reference.

 [1]: http://www.zlib.net/zlib_faq.html#faq05
 */
@interface TDTCocoaZBufferErrorTests : XCTestCase

@end

@implementation TDTCocoaZBufferErrorTests

- (void)testDecompressNoInput {
  TDTZDecompressor *decompressor = [[TDTZDecompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];

  XCTAssertNotNil([decompressor decompressData:nil]);
}

- (void)testDecompressNoInputFinish {
  TDTZDecompressor *decompressor = [[TDTZDecompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];

  XCTAssertNotNil([decompressor finishData:nil]);
}

- (void)testDecompressFlushWithoutData {
  TDTZDecompressor *decompressor = [[TDTZDecompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];

  XCTAssertNotNil([decompressor decompressData:[self someCompressedDeflateData]]);
  XCTAssertNotNil([decompressor flushData:nil]);
  XCTAssertNotNil([decompressor flushData:nil]);
}

- (NSData *)someCompressedDeflateData {
  NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  TDTZCompressor *compressor = [[TDTZCompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
  return [compressor finishData:data];
}

- (void)testCompressBufferResizingOnFinishWithSmallBuffer {
  TDTZCompressor *compressor = [[TDTZCompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
  compressor.outBufferChunkSize = 32;

  XCTAssertNotNil([compressor finishData:randomLargeData()]);
}

- (void)testCompressBufferResizingOnFinishWithSmallBufferAndPendingOutput {
  TDTZCompressor *compressor = [[TDTZCompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];
  compressor.outBufferChunkSize = 32;

  XCTAssertNotNil([compressor compressData:randomLargeData()]);
  XCTAssertNotNil([compressor finishData:nil]);
}

- (void)testCompressFlushWithoutData {
  TDTZCompressor *compressor = [[TDTZCompressor alloc] initWithCompressionFormat:TDTCompressionFormatDeflate];

  NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNotNil([compressor compressData:data]);
  XCTAssertNotNil([compressor flushData:nil]);
  XCTAssertNotNil([compressor flushData:nil]);
}

@end
