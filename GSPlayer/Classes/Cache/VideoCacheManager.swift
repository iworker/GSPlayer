//
//  VideoCacheManager.swift
//  GSPlayer
//
//  Created by Gesen on 2019/4/20.
//  Copyright © 2019 Gesen. All rights reserved.
//

import Foundation

private let directory = NSTemporaryDirectory().appendingPathComponent("GSPlayer")

public enum VideoCacheManager {
    
    public static func cachedFilePath(for url: URL) -> String {
        return directory
            .appendingPathComponent(url.absoluteString.md5)
            .appendingPathExtension(url.pathExtension)!
    }
    
    public static func cachedConfiguration(for url: URL) throws -> VideoCacheConfiguration {
        return try VideoCacheConfiguration
            .configuration(for: cachedFilePath(for: url))
    }
    
    public static func calculateCachedSize() -> UInt {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
        
        let fileContents = (try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)) ?? []
        
        return fileContents.reduce(0) { size, fileContent in
            guard
                let resourceValues = try? fileContent.resourceValues(forKeys: resourceKeys),
                resourceValues.isDirectory != true,
                let fileSize = resourceValues.totalFileAllocatedSize
                else { return size }
            
            return size + UInt(fileSize)
        }
    }
    
    public static func cleanAllCache() throws {
        let fileManager = FileManager.default
        let fileContents = try fileManager.contentsOfDirectory(atPath: directory)
        
        for fileContent in fileContents {
            let filePath = directory.appendingPathComponent(fileContent)
            try fileManager.removeItem(atPath: filePath)
        }
    }

    public static func cacheLocalFile(localURL: URL, remoteURL url: URL) throws {
      let fileManager = FileManager.default

      if !fileManager.fileExists(atPath: localURL.path) {
        throw NSError(
            domain: "me.gesen.player.cache",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Local file doesn't exist"]
        )
      }

      let localFileAttributes = try fileManager.attributesOfItem(atPath: localURL.path)
      let localFileSize =  Int(truncatingIfNeeded: localFileAttributes[FileAttributeKey.size] as! Int64)

      let filePath = VideoCacheManager.cachedFilePath(for: url)
      let fileDirectory = filePath.deletingLastPathComponent

      if !fileManager.fileExists(atPath: fileDirectory) {
          try fileManager.createDirectory(
              atPath: fileDirectory,
              withIntermediateDirectories: true,
              attributes: nil
          )
      }

      if fileManager.fileExists(atPath: filePath) {
          try fileManager.removeItem(atPath: filePath)
      }

      let configurationFilePath = VideoCacheConfiguration.configurationFilePath(for: filePath)

      if fileManager.fileExists(atPath: configurationFilePath) {
          try fileManager.removeItem(atPath: configurationFilePath)
      }

      var configuration = try VideoCacheConfiguration.configuration(for: filePath)

      configuration.info = .init(
        contentLength: localFileSize,
        contentType: "",
        isByteRangeAccessSupported: false
      )

      try fileManager.copyItem(atPath: localURL.path, toPath: filePath)
      configuration.add(fragment: .init(location: 0, length: localFileSize))
      configuration.save()
    }
}
