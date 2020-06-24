//
//  mixin.swift
//  
//
//  Created by Kevin Carter on 6/11/20.
//

import Foundation
import CommonCrypto

import Logging

import os


let logger = Logger(label: "octahe")


func PlatformArgs() -> Dictionary<String, String> {
    // Sourced from local machine
    //    BUILDPLATFORM - platform of the node performing the build.
    //    BUILDOS - OS component of BUILDPLATFORM
    //    BUILDARCH - architecture component of BUILDPLATFORM
    //    BUILDVARIANT - variant component of BUILDPLATFORM
    var platform = [String: String]()
    #if os(Linux)
        platform["BUILDOS"] = "linux"
    #else
        platform["BUILDOS"] = "darwin"
    #endif
    #if arch(x86_64)
        platform["BUILDARCH"] = "amd64"
    #elseif arch(arm64)
        platform["BUILDARCH"] = "arm64"
    #endif
    platform["BUILDPLATFORM"] = platform["BUILDOS"]! + "/" + platform["BUILDARCH"]!
    return platform
}


func BuildDictionary(filteredContent: [(key: String, value: String)]) -> Dictionary<String, String> {
    func Trimmer(item: Substring, trimitems: CharacterSet = ["\""]) -> String {
        let cleanedItem = item.replacingOccurrences(of: "\\ ", with: " ")
        return cleanedItem.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: trimitems)
    }
    
    func matches(text: String) -> Array<String> {
        let regex = "(?:\"(.*?)\"|(\\w+))=(?:\"(.*?)\"|(\\w+))"
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(
                in: text,
                range: NSRange(
                    text.startIndex...,
                    in: text
                )
            )
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            logger.warning("\(error.localizedDescription)")
            return []
        }
    }

    let data = filteredContent.map{$0.value}.reduce(into: [String: String]()) {
        var argArray: Array<Array<Substring>> = []
        if $1.contains("=") {
            let regexArgsMap = matches(text: $1)
            for arg in regexArgsMap {
                argArray.append(arg.split(separator: "=", maxSplits: 1))
            }
        } else {
            argArray.append($1.split(separator: " ", maxSplits: 1))
        }
        for itemSet in argArray {
            if let key = itemSet.first, let value = itemSet.last {
                let trimmedKey = Trimmer(item: key)
                let trimmedValue = Trimmer(item: value, trimitems: ["\"", "\\"])
                $0[trimmedKey] = trimmedValue
            }
        }
    }
    return data
}


extension String {
    // String extension allowing us to evaluate if any string is actually an Int.
    var isInt: Bool {
        return Int(self) != nil
    }

    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func trunc(length: Int, trailing: String = " ...") -> String {
        if self.count <= length {
            return self
        }
        let truncated = self.prefix(length)
        return truncated + trailing
    }
}


extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    func getNextElement(index: Int) -> Element? {
        let nextIndex = index + 1
        let isValidIndex = nextIndex >= 0 && nextIndex < count
        return isValidIndex ? self[nextIndex] : nil
    }
}
