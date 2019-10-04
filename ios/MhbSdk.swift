//
//  MhbSdk.swift
//  RNLibMhb
//
//  Created by iamlockon on 2019/9/9.
//  Copyright © 2019 Facebook. All rights reserved.
//
import UIKit
import Foundation
import MHBSdk

enum SDKError: Error {
    case runtimeError(String)
}

@objc(MhbSdk)
class MhbSdk: NSObject, MHBDelegate {
    private let API_KEY = Key.MHBSDK.API_KEY
    private var file: Data?
    private var serverKey: String?
    private var startProcError: String?
    private var fetchFailError: String?
    private var isFetchSuccess: Bool = false
    override init() {
        let mhb = MHB.configure(APIKey: self.API_KEY)
    }

    func didStartProcSuccess() {
    }
    
    func didStartProcFalure(error: String) {
        self.startProcError = error
    }
    
    func didFetchDataSuccess(file: Data, serverKey: String) {
        self.file = file
        self.serverKey = serverKey
        self.isFetchSuccess = true
    }
    
    func didFetchDataFailure(error: String) {
        self.fetchFailError = error
    }
    
    func writeDataToZipFile(data: Data) throws -> String {
        //See https://www.hangge.com/blog/cache/detail_527.html
        let manager = FileManager.default
        let urlsForDocDirectory = manager.urls(for:.documentDirectory, in:.userDomainMask)
        let docPath = urlsForDocDirectory[0]
        let file = docPath.appendingPathComponent("temp.zip") //return URL
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let writeHandler = try FileHandle(forWritingTo:file)
        writeHandler.seekToEndOfFile()
        writeHandler.write(data)
        return file.path
    }
    
    func unZipFileWithPassword(zipPath: String) throws -> String {
        let unzipPath = tempUnzipPath()!
        let key = self.API_KEY + self.serverKey!
        try SSZipArchive.unzipFile(atPath: zipPath,
                                       toDestination: unzipPath,
                                       overwrite: true,
                                       password: key)
        return unzipPath
    }
    
    func readDataFromFile(filePath: String) throws -> String {
        let fileManager = FileManager.default
        let directoryURL: URL = URL.init(string: filePath)!

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            // process files
            let readHandler = try! FileHandle(forReadingFrom: fileURLs[0])
            let data = readHandler.readDataToEndOfFile()
            let readString = String(data: data, encoding: String.Encoding.utf8)
            return readString!
        } catch {
            print("Error while enumerating files \(directoryURL.path): \(error.localizedDescription)")
            throw error
        }
    }
    
    @objc
    func startProc(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        //先清File Tickets, 避免errorCode 101
        let arr = UserDefaults.standard.dictionaryRepresentation()
        for item in arr {
            if item.key.contains("File_Ticket_") {
                UserDefaults.standard.removeObject(forKey: item.key)
            }
        }
        MHB.start(self)
        if (self.startProcError != nil) {
            reject(self.startProcError, self.startProcError, nil)
        } else {
            resolve("OK")
        }
    }
    
    @objc
    func fetchData(_ startTimestamp: String, ets endTimestamp: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        //var arrR: [String] = []
        let arr = UserDefaults.standard.dictionaryRepresentation()
        let _startTimestamp: Int = Int(startTimestamp)! / 1000
        let _endTimestamp: Int = Int(endTimestamp)! / 1000
        //先iterate一遍檢查有沒有符合的File Ticket
        var hasValidFileTicket: Bool = false
        for item in arr {
            if item.key.contains("File_Ticket_") {
                let timeStamp: Int = Int(item.key.components(separatedBy: "ket_")[1])!
                if (_startTimestamp < timeStamp && _endTimestamp > timeStamp) {
                    hasValidFileTicket = true
                }
            }
        }
        if (hasValidFileTicket == false) {
            reject(Key.ErrorMessage.noValidFileTicket, Key.ErrorMessage.noValidFileTicket, nil)
            return
        }
        
        for item in arr {
            if item.key.contains("File_Ticket_") {
                //依照start time/end time查詢前次SDK存入的File Ticket.
                let timeStamp: Int = Int(item.key.components(separatedBy: "ket_")[1])!
                if (_startTimestamp < timeStamp && _endTimestamp > timeStamp) {
                    MHB.fetchData(self, fileTicket: item.key)

                    while (true) {
                        if (self.isFetchSuccess) {
                            break
                        }
                        if (self.fetchFailError != nil) {
                            reject(self.fetchFailError, self.fetchFailError, nil)
                            return
                        }
                    }
                    
                    if (self.file != nil && self.serverKey != nil) {
                        do {
                            let zipPath = try self.writeDataToZipFile(data: self.file!)
                            let unzipFilePath = try self.unZipFileWithPassword(zipPath: zipPath)
                            let data = try self.readDataFromFile(filePath: unzipFilePath)
                            resolve(data)
                            return
                        } catch {
                            reject(error.localizedDescription, error.localizedDescription, nil)
                        }
                        
                    } else {
                        self.fetchFailError = Key.ErrorMessage.fetchDataNil
                        reject(self.fetchFailError, self.fetchFailError, nil)
                    }
                    
                }
            }
        }
    }
    
    //Utils Function, See https://github.com/ZipArchive/ZipArchive/blob/master/Example/SwiftExample/ViewController.swift
    
    func tempZipPath() -> String {
        var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        path += "/\(UUID().uuidString).zip"
        return path
    }
    
    func tempUnzipPath() -> String? {
        var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        path += "/\(UUID().uuidString)"
        let url = URL(fileURLWithPath: path)
        
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        return url.path
    }
}
