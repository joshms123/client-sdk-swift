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
/// on its Opus fmtp (RFC 7587 §6.1): libwebrtc configures each m-line's
/// decoder channel count from the LOCAL description and defaults to mono
/// otherwise.
///
/// Munging is PER MEDIA SECTION: payload type numbers repeat across
/// m-sections (every subscribed track has its own `a=fmtp:111 …`), so a
/// global first-match patches only the first audio section — every later
/// section's decoder is born mono, discards the stereo side channel, and a
/// track subscribed after the first stays dual-mono until a fresh
/// connection (the stale-mono-subscription bug).
enum OpusStereoSdp {
    static func enableReceive(in sdp: String) -> String {
        let lines = sdp.components(separatedBy: "\r\n")

        // Split into the session header plus one chunk per m-section.
        var sections: [[String]] = [[]]
        for line in lines {
            if line.hasPrefix("m=") {
                sections.append([line])
            } else {
                sections[sections.count - 1].append(line)
            }
        }

        for index in sections.indices where sections[index].first?.hasPrefix("m=audio") == true {
            var section = sections[index]

            var opusPayloadTypes: [String] = []
            for line in section where line.hasPrefix("a=rtpmap:") && line.lowercased().contains(" opus/") {
                if let pt = line.dropFirst("a=rtpmap:".count).split(separator: " ").first {
                    opusPayloadTypes.append(String(pt))
                }
            }

            for pt in opusPayloadTypes {
                let fmtpPrefix = "a=fmtp:\(pt) "
                if let fmtpIndex = section.firstIndex(where: { $0.hasPrefix(fmtpPrefix) }) {
                    if !section[fmtpIndex].contains("stereo=") {
                        section[fmtpIndex] += ";stereo=1;sprop-stereo=1"
                    }
                } else if let rtpmapIndex = section.firstIndex(where: { $0.hasPrefix("a=rtpmap:\(pt) ") }) {
                    section.insert("a=fmtp:\(pt) stereo=1;sprop-stereo=1", at: rtpmapIndex + 1)
                }
            }

            sections[index] = section
        }

        return sections.flatMap { $0 }.joined(separator: "\r\n")
    }
}
