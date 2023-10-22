//
//  FileReader.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 21/10/2023.
//

import Foundation
import System

extension FilePath {
  func readLines(_ handler: (String) throws -> Void) throws {
    var err: Error? = nil
    let content: String
    do {
      content = try String(contentsOfFile: string)
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
