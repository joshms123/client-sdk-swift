/*
 * Copyright 2026 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/// Opus stereo RECEIVE requires the answering side to advertise `stereo=1`
/// on its Opus fmtp (RFC 7587 §6.1): libwebrtc configures the decoder's
/// channel count from the LOCAL description and defaults to mono otherwise
/// (browsers ship the stereo-by-default field trial; native builds do not),
/// so a stereo broadcast decodes mono without this.
enum OpusStereoSdp {
    static func enableReceive(in sdp: String) -> String {
        var lines = sdp.components(separatedBy: "\r\n")

        // Opus payload types: "a=rtpmap:<pt> opus/48000/2"
        var opusPayloadTypes: [String] = []
        for line in lines where line.hasPrefix("a=rtpmap:") && line.lowercased().contains(" opus/") {
            if let pt = line.dropFirst("a=rtpmap:".count).split(separator: " ").first {
                opusPayloadTypes.append(String(pt))
            }
        }
        guard !opusPayloadTypes.isEmpty else { return sdp }

        for pt in opusPayloadTypes {
            let fmtpPrefix = "a=fmtp:\(pt) "
            if let index = lines.firstIndex(where: { $0.hasPrefix(fmtpPrefix) }) {
                if !lines[index].contains("stereo=") {
                    lines[index] += ";stereo=1;sprop-stereo=1"
                }
            } else if let rtpmapIndex = lines.firstIndex(where: { $0.hasPrefix("a=rtpmap:\(pt) ") }) {
                lines.insert("a=fmtp:\(pt) stereo=1;sprop-stereo=1", at: rtpmapIndex + 1)
            }
        }
        return lines.joined(separator: "\r\n")
    }
}
