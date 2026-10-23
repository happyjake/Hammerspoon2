import XCTest
import Foundation
import Darwin
@testable import Hammerspoon_2

nonisolated final class HSHttpParserTests: XCTestCase {
    func testLargeBodyThenFragmentedPipelinedRequest() throws {
        let parser = HSHttpParser()
        var bytes = Data("POST /large HTTP/1.1\r\nContent-Length: 8388608\r\n\r\n".utf8)
        bytes.append(Data(repeating: 120, count: 8 * 1024 * 1024))
        bytes.append(Data("POST /small HTTP/1.1\r\nContent-Length: 3\r\n\r\na".utf8))
        parser.append(bytes)
        let large = try XCTUnwrap(parser.takeIfComplete())
        XCTAssertEqual(large.body.count, 8 * 1024 * 1024)
        parser.append(Data("bc".utf8))
        let small = try XCTUnwrap(parser.takeIfComplete())
        XCTAssertEqual(small.target, "/small")
        XCTAssertEqual(small.body, Data("abc".utf8))
    }

    func testFragmentedChunkedBodyPreservesNextRequest() throws {
        let parser = HSHttpParser()
        let bytes = Data(("POST /chunked HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n" +
            "3\r\nabc\r\n2\r\nde\r\n0\r\nX-Trailer: yes\r\n\r\n").utf8)
        for byte in bytes { parser.append(Data([byte])) }
        XCTAssertEqual(try XCTUnwrap(parser.takeIfComplete()).body, Data("abcde".utf8))
        parser.append(Data("GET /one HTTP/1.1\r\n\r\nGET /two HTTP/1.1\r\n\r\n".utf8))
        XCTAssertEqual(try XCTUnwrap(parser.takeIfComplete()).target, "/one")
        parser.append(Data())
        XCTAssertEqual(try XCTUnwrap(parser.takeIfComplete()).target, "/two")
    }

    private func allocatedBytes() -> Int {
        var stats = malloc_statistics_t()
        unsafe malloc_zone_statistics(nil, &stats)
        return Int(stats.size_in_use)
    }

    func testCompletedParsersReleaseLargeAllocationsWithSmallPipelineTails() throws {
        let parsers = (0..<10).map { _ in HSHttpParser() }
        let baseline = allocatedBytes()
        for parser in parsers {
            autoreleasepool {
                var bytes = Data("POST / HTTP/1.1\r\nContent-Length: 8388608\r\n\r\n".utf8)
                bytes.append(Data(repeating: 120, count: 8 * 1024 * 1024))
                bytes.append(Data("GET /next HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8))
                parser.append(bytes)
            }
        }
        // Positive control: the same observable must see the retained bodies.
        XCTAssertGreaterThan(allocatedBytes() - baseline, 70 * 1024 * 1024)
        for parser in parsers {
            autoreleasepool {
                XCTAssertEqual(parser.takeIfComplete()?.body.count, 8 * 1024 * 1024)
            }
        }
        XCTAssertLessThan(allocatedBytes() - baseline, 8 * 1024 * 1024)
        for parser in parsers {
            parser.append(Data())
            XCTAssertEqual(try XCTUnwrap(parser.takeIfComplete()).target, "/next")
        }
    }
}
