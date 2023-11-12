//
//  FileReader.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation
import System

// When using async, it is easier to simply use URL.lines.
extension FilePath {
  func readLines(_ handler: (String) throws -> Void) throws {
    var err: (any Error)? = nil
    let content: String
    do {
      content = try String(contentsOfFile: (string as NSString).expandingTildeInPath)
    } catch CocoaError.fileReadNoSuchFile {
      return
    } catch {
      throw error
    }
    withoutActuallyEscaping(handler) { escapingClosure in
      content.enumerateLines { line, stop in
        do {
          try escapingClosure(line)
        } catch {
          stop = true
          err = error
        }
      }
    }
    
    if let err {
      throw err
    }
  }
}
