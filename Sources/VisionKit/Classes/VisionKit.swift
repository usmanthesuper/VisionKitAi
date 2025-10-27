//
//  Roboflow.swift
//  Roboflow
//
//  Created by Nicholas Arner on 4/12/22.
//

import CoreML
import Vision
import Foundation

///Interface for interacting with the Roboflow API
public class VisionKitMobile: NSObject {
    
    var apiKey: String!
    var deviceID: String!
    private var retries = 2
    private var apiURL: String!

    //Initalize the SDK with the user's authorization key
    public init (apiKey: String, apiURL: String = "https://api.roboflow.com") {
        super.init()
        self.apiKey = apiKey
        self.apiURL = apiURL
        
        //Generate a unique device ID
        #if os(iOS) || os(macOS)
        if #available(iOS 16.0, macOS 12.0, *) {
            guard let deviceID = getDeviceId() else {
                fatalError("Failed to generate device ID")
            }
            self.deviceID = deviceID
        } else {
            // Fallback for earlier versions - generate a UUID
            self.deviceID = UUID().uuidString
        }
        #else
        // Fallback for other platforms - generate a UUID
        self.deviceID = UUID().uuidString
        #endif
    }
    
    func getModelClass(modelType: String) -> RFModel {
        if (modelType.contains("seg")) {
            return RFInstanceSegmentationModel()
        }
        if (modelType.contains("vit") || modelType.contains("resnet")) {
            return RFClassificationModel()
        }
        if (modelType.contains("detr") || modelType.contains("rfdetr")) {
            return RFDetrObjectDetectionModel()
        }
        return RFObjectDetectionModel()
    }
    
    //Start the process of fetching the CoreMLModel
    @available(*, renamed: "load(model:modelVersion:)")
    public func load(model: String, modelVersion: Int, completion: @escaping (RFModel?, Error?, String, String)->()) {
        if let modelInfo = loadModelCache(modelName: model, modelVersion: modelVersion),
            let modelURL = modelInfo["compiledModelURL"] as? String,
            let colors = modelInfo["colors"] as? [String: String],
            let classes = modelInfo["classes"] as? [String],
            let name = modelInfo["name"] as? String,
            let modelType = modelInfo["modelType"] as? String,
            let environment = modelInfo["environment"] as? [String: Any] {
            
            getConfigDataBackground(modelName: model, modelVersion: modelVersion, apiKey: apiKey, deviceID: deviceID)
            
            let modelObject = getModelClass(modelType: modelType)

            do {
                let documentsURL = try FileManager.default.url(for: .documentDirectory,
                                                                in: .userDomainMask,
                                                                appropriateFor: nil,
                                                                create: false)
                _ = modelObject.loadMLModel(modelPath: documentsURL.appendingPathComponent(modelURL), colors: colors, classes: classes, environment: environment)
                
                completion(modelObject, nil, name, modelType)
            } catch {
                clearAndRetryLoadingModel(model, modelVersion, completion)
            }
        } else if retries > 0 {
            clearModelCache(modelName: model, modelVersion: modelVersion)
            retries -= 1
            getModelData(modelName: model, modelVersion: modelVersion, apiKey: apiKey, deviceID: deviceID) { [self] fetchedModel, error, modelName, modelType, colors, classes, environment in
                if let err = error {
                    completion(nil, err, "", "")
                } else if let fetchedModel = fetchedModel {
                    let modelObject = getModelClass(modelType: modelType)
                    _ = modelObject.loadMLModel(modelPath: fetchedModel, colors: colors ?? [:], classes: classes ?? [], environment: environment ?? [:])
                    completion(modelObject, nil, modelName, modelType)
                } else {
                    clearAndRetryLoadingModel(model, modelVersion, completion)
                }
            }
        } else {
            print("Error Loading Model. Check your API_KEY, project name, and version along with your network connection.")
            completion(nil, ModelLoadError(), "", "")
        }
    }

    private func clearAndRetryLoadingModel(_ model: String, _ modelVersion: Int, _ completion: @escaping (RFModel?, Error?, String, String)->()) {
        clearModelCache(modelName: model, modelVersion: modelVersion)
        self.load(model: model, modelVersion: modelVersion, completion: completion)
    }

    public func load(model: String, modelVersion: Int) async -> (RFModel?, Error?, String, String) {
        if #available(macOS 10.15, *) {
            return await withCheckedContinuation { continuation in
                load(model: model, modelVersion: modelVersion) { result1, result2, result3, result4 in
                    continuation.resume(returning: (result1, result2, result3, result4))
                }
            }
        } else {
            // Fallback on earlier versions
            return (nil, ModelLoadError(), "", "")
        }
    }
    
    func getConfigData(modelName: String, modelVersion: Int, apiKey: String, deviceID: String, completion: @escaping (([String: Any]?, Error?) -> Void)) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "nobundle"
        guard let apiURL = URL(string: self.apiURL) else {
            return completion(nil, ModelLoadError())
        }
        var request = URLRequest(url: URL(string: "\(String(describing: apiURL))/coreml/\(modelName)/\(String(modelVersion))?api_key=\(apiKey)&device=\(deviceID)&bundle=\(bundleIdentifier)")!,timeoutInterval: Double.infinity)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"
        
        // Execute Post Request
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            
            // Parse Response to String
            guard let data = data else {
                completion(nil, error)
                return
            }
            
            // Convert Response String to Dictionary
            do {
                let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                completion(dict, nil)
                
            } catch {
                completion(nil, error.localizedDescription)
            }
        }).resume()
    }
    
    private func getConfigDataBackground(modelName: String, modelVersion: Int, apiKey: String, deviceID: String) {
        DispatchQueue.global(qos: .background).async {
            self.getConfigData(modelName: modelName, modelVersion: modelVersion, apiKey: apiKey, deviceID: deviceID, completion: {_,_ in })
        }
    }
    
    
    //Get the model metadata from the Roboflow API
    private func getModelData(modelName: String, modelVersion: Int, apiKey: String, deviceID: String, completion: @escaping (URL?, Error?, String, String, [String: String]?, [String]?, [String: Any]?)->()) {
        getConfigData(modelName: modelName, modelVersion: modelVersion, apiKey: apiKey, deviceID: deviceID) { data, error in
            if let error = error {
                completion(nil, error, "", "", nil, nil, nil)
                return
            }
            
            guard let data = data,
                  let coreMLDict = data["coreml"] as? [String: Any],
                  let name = coreMLDict["name"] as? String,
                  let modelType = coreMLDict["modelType"] as? String,
                  let modelURLString = coreMLDict["model"] as? String,
                  let modelURL = URL(string: modelURLString) else {
                completion(nil, error, "", "", nil, nil, nil)
                return
            }
            
            let colors = coreMLDict["colors"] as? [String: String]
            var classes = coreMLDict["classes"] as? [String]

            let environment = coreMLDict["environment"] as? String

            // download json file at the url in `environment`
            let environmentURL = URL(string: environment!)
            let environmentData = try? Data(contentsOf: environmentURL!)
            let environmentDict = try? JSONSerialization.jsonObject(with: environmentData!, options: []) as? [String: Any]

            // get `"CLASS_LIST"` from the json
            let classList = environmentDict?["CLASS_LIST"] as? [String]
            if let classList = classList {
                classes = classList
            }
            
            //Download the model from the link in the API response
            self.downloadModelFile(modelName: "\(modelName)-\(modelVersion).mlmodel", modelVersion: modelVersion, modelURL: modelURL) { fetchedModel, error in
                if let error = error {
                    completion(nil, error, "", "", nil, nil, nil)
                    return
                }
                
                if let fetchedModel = fetchedModel {
                    _ = self.cacheModelInfo(modelName: modelName, modelVersion: modelVersion, colors: colors ?? [:], classes: classes ?? [], name: name, modelType: modelType, compiledModelURL: fetchedModel, environment: environmentDict ?? [:])
                    completion(fetchedModel, nil, name, modelType, colors, classes, environmentDict)
                } else {
                    completion(nil, error, "", "", nil, nil, nil)
                }
            }
        }
    }


    private func cacheModelInfo(modelName: String, modelVersion: Int, colors: [String: String], classes: [String], name: String, modelType: String, compiledModelURL: URL, environment: [String: Any]) -> [String: Any]? {
        let modelInfo: [String : Any] = [
            "colors": colors,
            "classes": classes,
            "name": name,
            "modelType": modelType,
            "compiledModelURL": compiledModelURL.lastPathComponent,
            "environment": environment
        ]
        
        do {
            let encodedData = try NSKeyedArchiver.archivedData(withRootObject: modelInfo, requiringSecureCoding: true)
            UserDefaults.standard.set(encodedData, forKey: "\(modelName)-\(modelVersion)")
            return modelInfo
        } catch {
            print("Error while caching model info: \(error.localizedDescription)")
            return nil
        }
    }
        
    private func loadModelCache(modelName: String, modelVersion: Int) -> [String: Any]? {
        do {
            if let modelInfoData = UserDefaults.standard.data(forKey: "\(modelName)-\(modelVersion)") {
                let decodedData = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSArray.self, NSNumber.self], from: modelInfoData) as? [String: Any]
                return decodedData
            }
        } catch {
            print("Error unarchiving data: \(error.localizedDescription)")
        }
        return nil
    }

    public func clearModelCache(modelName: String, modelVersion: Int) {
        UserDefaults.standard.removeObject(forKey: "\(modelName)-\(modelVersion)")
    }
    
    //Download the model link with the provided URL from the Roboflow API
    private func downloadModelFile(modelName: String, modelVersion: Int, modelURL: URL, completion: @escaping (URL?, Error?)->()) {
        
        downloadModel(signedURL: modelURL) { url, originalURL in
            if url != nil {
                do {
                    var finalModelURL = url!
                    
                    // Check if the original URL or downloaded file indicates a zip file
                    let isZipFile = originalURL?.pathExtension.lowercased() == "zip" || 
                                  originalURL?.absoluteString.contains(".zip") == true
                    
                    if isZipFile {
                        // Unzip the file and find the .mlmodel file
                        finalModelURL = try self.unzipModelFile(zipURL: finalModelURL)
                    }
                                    
                    //Compile the downloaded model
                    let compiledModelURL = try MLModel.compileModel(at: finalModelURL)
                    
                    // Ensure Documents directory exists
                    let documentsURL = try FileManager.default.url(for: .documentDirectory,
                                                                    in: .userDomainMask,
                                                                    appropriateFor: nil,
                                                                    create: true)
                    
                    let savedURL = documentsURL.appendingPathComponent("\(modelName)-\(modelVersion).mlmodelc")
                    
                    // Check if the compiled model exists
                    guard FileManager.default.fileExists(atPath: compiledModelURL.path) else {
                        let error = NSError(domain: "ModelCompilationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Compiled model does not exist at: \(compiledModelURL.path)"])
                        completion(nil, error)
                        return
                    }
                    
                    // Remove existing file if it exists
                    if FileManager.default.fileExists(atPath: savedURL.path) {
                        try FileManager.default.removeItem(at: savedURL)
                    }
                    
                    // Move the compiled model
                    do {
                        try FileManager.default.moveItem(at: compiledModelURL, to: savedURL)
                    } catch {
                        // If move fails, try copying instead
                        do {
                            try FileManager.default.copyItem(at: compiledModelURL, to: savedURL)
                        } catch {
                            completion(nil, error)
                            return
                        }
                    }
                    
                    completion(savedURL, nil)
                } catch {
                    print("Model compilation/processing error: \(error.localizedDescription)")
                    completion(nil, error)
                }
            } else {
                let error = NSError(domain: "DownloadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to download model"])
                completion(nil, error)
            }
        }
    }
    
    // Helper function to unzip a file and return the path to the .mlmodel file
    private func unzipModelFile(zipURL: URL) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let extractionDirectory = tempDirectory.appendingPathComponent(UUID().uuidString)
        
        // Create extraction directory
        try FileManager.default.createDirectory(at: extractionDirectory, withIntermediateDirectories: true, attributes: nil)
        
        #if os(macOS)
        // Use command line unzip on macOS
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", extractionDirectory.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "UnzipError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to unzip file"])
        }
        #else
        // Use iOS-compatible zip extraction
        try ZipExtractor.extractZip(zipURL: zipURL, to: extractionDirectory)
        #endif
        
        // Find the .mlmodel or .mlpackage file in the extracted directory
        let result = try findModelFile(in: extractionDirectory)
        
        // Note: Don't clean up extraction directory here - let the system handle cleanup
        // The temp directory will be cleaned up automatically by the OS
        
        return result
    }
    
    private func findModelFile(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
        
        // First, look for .mlmodel or .mlpackage files directly
        for url in contents {
            let ext = url.pathExtension.lowercased()
            if ext == "mlmodel" || ext == "mlpackage" {
                return url
            }
        }
        
        // If not found, search recursively
        for url in contents {
            if url.hasDirectoryPath {
                do {
                    return try findModelFile(in: url)
                } catch {
                    // Continue searching in other directories
                    continue
                }
            }
        }
        
        throw NSError(domain: "UnzipError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No .mlmodel or .mlpackage file found in the zip archive"])
    }
    
    func downloadModel(signedURL: URL, completion: @escaping ((URL?, URL?) -> Void)) {
        let downloadTask = URLSession.shared.downloadTask(with: signedURL) {
            urlOrNil, responseOrNil, errorOrNil in
            guard let fileURL = urlOrNil else {
                completion(nil, nil)
                return
            }
            completion(fileURL, signedURL)
        }
        downloadTask.resume()
    }
}

