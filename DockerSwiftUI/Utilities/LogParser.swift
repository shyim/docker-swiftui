import Foundation

enum LogParser {
    /// Parse Docker multiplexed log stream.
    /// Docker uses an 8-byte header per frame when TTY is disabled:
    /// - Byte 0: stream type (0=stdin, 1=stdout, 2=stderr)
    /// - Bytes 1-3: padding (zeros)
    /// - Bytes 4-7: payload size as big-endian UInt32
    /// When TTY is enabled, the stream is raw text with no headers.
    static func parse(_ data: Data) -> String {
        // Try multiplexed format first
        guard data.count >= 8 else {
            return String(data: data, encoding: .utf8) ?? ""
        }

        // Check if this looks like multiplexed format:
        // byte 0 should be 0, 1, or 2; bytes 1-3 should be 0
        let firstByte = data[data.startIndex]
        let byte1 = data[data.startIndex + 1]
        let byte2 = data[data.startIndex + 2]
        let byte3 = data[data.startIndex + 3]

        let looksMultiplexed = (firstByte <= 2) && (byte1 == 0) && (byte2 == 0) && (byte3 == 0)

        guard looksMultiplexed else {
            return String(data: data, encoding: .utf8) ?? ""
        }

        // Copy to ensure contiguous, zero-based buffer
        let bytes = [UInt8](data)
        var result = ""
        var offset = 0

        while offset + 8 <= bytes.count {
            let size = UInt32(bytes[offset + 4]) << 24
                     | UInt32(bytes[offset + 5]) << 16
                     | UInt32(bytes[offset + 6]) << 8
                     | UInt32(bytes[offset + 7])

            let payloadStart = offset + 8
            let payloadEnd = payloadStart + Int(size)

            guard payloadEnd <= bytes.count else { break }

            if let text = String(bytes: bytes[payloadStart ..< payloadEnd], encoding: .utf8) {
                result += text
            }

            offset = payloadEnd
        }

        if result.isEmpty {
            return String(data: data, encoding: .utf8) ?? ""
        }

        return result
    }
}
