//
//  ViewController.swift
//  ZoomSDK
//
//  Created by Sergey Pohrebnuak on 4/5/19.
//  Copyright © 2019 Sergey Pohrebnuak. All rights reserved.
//

import UIKit
import ZoomAuthenticationHybrid
import LocalAuthentication

class ViewController: UIViewController, ZoomVerificationDelegate, URLSessionDelegate {

    @IBOutlet fileprivate weak var addUserButton: UIButton!
    
    let zoomServerBaseURL = "https://api.zoomauth.com/api/v1/biometrics";
    
    let licenseKey = "d0lRA0dhpYtBJaMu8wqiQ5LHSNXvmAOF"
    
    let publicKey =
        "-----BEGIN PUBLIC KEY-----\n" +
            "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5PxZ3DLj+zP6T6HFgzzk\n" +
            "M77LdzP3fojBoLasw7EfzvLMnJNUlyRb5m8e5QyyJxI+wRjsALHvFgLzGwxM8ehz\n" +
            "DqqBZed+f4w33GgQXFZOS4AOvyPbALgCYoLehigLAbbCNTkeY5RDcmmSI/sbp+s6\n" +
            "mAiAKKvCdIqe17bltZ/rfEoL3gPKEfLXeN549LTj3XBp0hvG4loQ6eC1E1tRzSkf\n" +
            "GJD4GIVvR+j12gXAaftj3ahfYxioBH7F7HQxzmWkwDyn3bqU54eaiB7f0ftsPpWM\n" +
            "ceUaqkL2DZUvgN0efEJjnWy5y1/Gkq5GGWCROI9XG/SwXJ30BbVUehTbVcD70+ZF\n" +
            "8QIDAQAB\n" +
    "-----END PUBLIC KEY-----"
    
    var sessionId: String!
    //var userIdentifier: String { return String(Int.random(in: 0 ... 1000000))}
    let userIdentifier = "gvyuh78yiu1"
    var lastAction: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Zoom.sdk.setFacemapEncryptionKey(publicKey: publicKey)
        Zoom.sdk.initialize(
            appToken: licenseKey,
            completion: { initializationSuccessful in
                self.addUserButton.isEnabled = initializationSuccessful
                print("ZoOm initialize success: \(initializationSuccessful)")
                if initializationSuccessful {
                    self.isUserEnrolled(callback: { (hasUser) in
                        if hasUser {
                            self.deleteUserEnrollment(callback: { (successDeleating) in
                                if successDeleating {
                                    self.startScaninng()
                                } else {
                                    print("Errror deleating!!!!")
                                }
                            })
                        } else {
                            self.startScaninng()
                        }
                    })
                }
        }
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async {
            Zoom.sdk.preload()
        }
    }
    
    @IBAction func didTapDeleteUыer(_ sender: Any) {
        //deleteUserEnrollment()
        //sendImageOnServer()
        //isUserEnrolled()
    }
    
    @IBAction func didTapAuthentication(_ sender: Any) {
        let customization: ZoomCustomization = ZoomCustomization()
        lastAction = "authenticate"
        customization.showPreEnrollmentScreen = false
        Zoom.sdk.setCustomization(customization)
        let zoomVerificationVC = Zoom.sdk.createVerificationVC(delegate: self)
        zoomVerificationVC.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        zoomVerificationVC.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        self.present(zoomVerificationVC, animated: true, completion: nil)
    }
    
    fileprivate func startScaninng() {
        let customization: ZoomCustomization = ZoomCustomization()
        lastAction = "enrollment"
        customization.showPreEnrollmentScreen = false
        Zoom.sdk.setCustomization(customization)
        let zoomVerificationVC = Zoom.sdk.createVerificationVC(delegate: self)
        zoomVerificationVC.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        zoomVerificationVC.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        self.present(zoomVerificationVC, animated: true, completion: nil)
    }
    
    @IBAction func didTapScanButton(_ sender: Any) {
        startScaninng()
    }
    
    // MARK: - Zoom verification deleagte function
    func onBeforeZoomDismiss(status: ZoomVerificationStatus, retryReason reason: ZoomRetryReason) -> Bool {
//        if(Zoom.sdk.isLockedOut() || status == .failedBecauseUserCancelled) {
//
//        }
        print("Some error or cancell")
        return false
    }
    
    func onZoomVerificationResult(result: ZoomVerificationResult) {
        print("get result")
        guard result.status.rawValue == 0 else {
            print("error scanning")
            return
        }
        
        let zoomFacemapStr: String = (result.faceMetrics?.zoomFacemap)!.base64EncodedString(options: [])
        var endpoint: String!
        var parameters: [String : Any] = [String: Any]()
        
        parameters["sessionId"] = result.sessionId
        sessionId = result.sessionId
        
        if lastAction == "enrollment" {
            registerNewUser(result: result)
            return
        }
        else if lastAction == "authenticate" {
            //authenticationUser(result: result)
            return
        }
        else if lastAction == "liveness" {
            endpoint = "/liveness"
            parameters["facemap"] = zoomFacemapStr
        }
        
        let request = buildHTTPRequest(method: "POST", endpoint: endpoint, parameters: parameters)
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { responseData, response, error in
            
            
            guard let responseData = responseData , error == nil else {
                print("error")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject]

                if self.lastAction == "liveness" {
                    if (json["data"] as? [String : Any])?["livenessResult"] as? String == "passed" {
                    }
                }
                
                
            }
            catch {
                print("Some error!!!")
            }
        })
        
        task.resume()
    }
    
    func buildHTTPRequest(method: String, endpoint: String, parameters: [String : Any]) -> NSMutableURLRequest {
        let request = NSMutableURLRequest(url: NSURL(string: zoomServerBaseURL + endpoint)! as URL)
        request.httpMethod = method
        // Only send data if there are parameters and this is not a GET request
        if parameters.count > 0 && method != "GET" {
            request.httpBody = try! JSONSerialization.data(withJSONObject: parameters as Any, options: JSONSerialization.WritingOptions(rawValue: 0))
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(licenseKey, forHTTPHeaderField: "X-App-Token")
        let sessionId: String = parameters["sessionId"] as? String ?? "nil"
                request.addValue("facetec|zoomsdk|ios|\(Bundle.main.bundleIdentifier!)|\(licenseKey)|\(UIDevice.current.zoomDeviceIdentifierForVendor)|\(UIDevice.current.modelName)|\(Zoom.sdk.version)|\(Locale.current.identifier)|\(Bundle.main.preferredLocalizations.first ?? "Unknown")|\(sessionId)",
                    forHTTPHeaderField: "User-Agent")
        
        return request
    }
    
    
    // MARK: - register new user
    fileprivate func registerNewUser(result: ZoomVerificationResult) {
        let zoomFacemapStr: String = (result.faceMetrics?.zoomFacemap)!.base64EncodedString(options: [])
        let endpoint = "/enrollment"
        var parameters: [String : Any] = [String: Any]()
        
        parameters["sessionId"] = result.sessionId
        parameters["enrollmentIdentifier"] = userIdentifier
        parameters["facemap"] = zoomFacemapStr
        
        let request = buildHTTPRequest(method: "POST", endpoint: endpoint, parameters: parameters)
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { responseData, response, error in
            
            guard let responseData = responseData , error == nil else {
                print("error")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject]
                
                if (json["data"] as? [String : Any])?["livenessResult"] as? String == "passed" {
                    print("User create")
                    self.sendImageOnServer()
                } else {
                    print("User NO Created some error!")
                }
            }
            catch {
                print("Some error!!!")
            }
        })
        task.resume()
    }
    
    // MARK: - delete user
    fileprivate func deleteUserEnrollment(callback: @escaping (Bool) -> Void ) {
        let endpoint: String = "/enrollment/\(userIdentifier)"
        var parameters: [String : Any] = [:]
        parameters["enrollmentIdentifier"] = userIdentifier
        
        let request = buildHTTPRequest(method: "DELETE", endpoint: endpoint, parameters: parameters)
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { responseData, response, error in
            
            guard let responseData = responseData , error == nil else {
                callback(false)
                print("Error")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.allowFragments) as! [String : AnyObject]
                callback(true)
                print("Successfull deleating user")
                return
            }
            catch {
                callback(false)
                print("Error deleating user")
            }
        })
        
        task.resume()
    }
    
    // MARK: - authentication user
    fileprivate func authenticationUser() {
        let endpoint = "/authenticate"
        var parameters: [String : Any] = [String: Any]()
        
        parameters["sessionId"] = generateUniqueUserIDMocked()
        parameters["source"] = ["enrollmentIdentifier": userIdentifier]
        parameters["targets"] = [["facemap":self.faceMapFromImage]]
        
        let request = buildHTTPRequest(method: "POST", endpoint: endpoint, parameters: parameters)
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { responseData, response, error in
            
            guard let responseData = responseData , error == nil else {
                print("error")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject]
                
                if ((json["data"] as? [String : Any])?["results"] as? [[String : AnyObject]])?[0]["authenticated"] as? Int == 1 {
                    print("User was authorization")
                } else {
                    print("User not enrolled or invalid enrollmentIdentifier")
                }
            }
            catch {
                print("Some error!!!")
            }
        })
        task.resume()
    }

    var faceMapFromImage: String!
    
    // MARK: - create facemap user from image
    fileprivate func sendImageOnServer() {
        
        let endpoint: String = "/facemap"
        var parameters: [String : Any] = [:]
        //parameters["images"] = [imageInBase64]
        let imageData: Data = UIImage.init(named: "sergFace")!.jpegData(compressionQuality: 1.0)!
        
        parameters["images"] = [imageData.base64EncodedString()]
        parameters["sessionId"] = generateUniqueUserIDMocked()
        
        let request = buildHTTPRequest(method: "POST", endpoint: endpoint, parameters: parameters)
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { responseData, response, error in
            
            guard let responseData = responseData , error == nil else {
                print("error")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.allowFragments) as! [String : AnyObject]
                if json["data"] != nil {
                    self.faceMapFromImage = json["data"] as? String
                    self.authenticationUser()
                    print("Successfull create face map")
                } else {
                    print("erro creating face map")
                }
                return
            }
            catch {
                print("Some error!!!")
            }
        })
        
        task.resume()
    }
    
    // MARK: - check user id
    func isUserEnrolled(callback: @escaping (Bool) -> Void) {
        
        let endpoint: String = "/enrollment/\(userIdentifier)"
        var parameters: [String : Any] = [:]
        parameters["enrollmentIdentifier"] = userIdentifier
        parameters["sessionId"] = generateUniqueUserIDMocked()
        
        let request = buildHTTPRequest(method: "GET", endpoint: endpoint, parameters: parameters)
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { responseData, response, error in
            
            guard let responseData = responseData , error == nil else {
                print("error")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.allowFragments) as! [String : AnyObject]
                print("enrolled: \(((json["meta"] as? [String : Any])?["ok"] as? Bool)!)")
                callback(((json["meta"] as? [String : Any])?["ok"] as? Bool)!)
                return
            }
            catch {
                print("Some error!!!")
            }
        })
        
        task.resume()
    }
    
    func generateUniqueUserIDMocked() -> String {
        let length = 14
        let symbols : NSString = "0123456789qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM"
        
        var randomString = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(UInt32(symbols.length))
            var nextChar = symbols.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }

}

private let deviceIdentifierSingleton: String = UIDevice.current.identifierForVendor?.uuidString ?? ""

extension UIDevice {
    var zoomDeviceIdentifierForVendor: String {
        return deviceIdentifierSingleton
    }
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8 , value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
        case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6":                return "iPhone X"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad6,11", "iPad6,12":                    return "iPad 5"
        case "iPad7,5", "iPad7,6":                      return "iPad 6"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4":                      return "iPad Pro 9.7 Inch"
        case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9 Inch"
        case "iPad7,1", "iPad7,2":                      return "iPad Pro 12.9 Inch 2. Generation"
        case "iPad7,3", "iPad7,4":                      return "iPad Pro 10.5 Inch"
        case "AppleTV5,3":                              return "Apple TV"
        case "AppleTV6,2":                              return "Apple TV 4K"
        case "AudioAccessory1,1":                       return "HomePod"
        default:                                        return identifier
        }
    }
}

extension UIImage {
    
    func convertImageToBase64() -> String {
        let imageData = self.jpegData(compressionQuality: 1)!
        return imageData.base64EncodedString(options: .lineLength64Characters)
    }
    
    func getImageSizeInB() -> Int {
        let imgData: NSData = NSData(data: self.jpegData(compressionQuality: 0.5)!)
        let imageSize = Double(imgData.length)
        return Int(imageSize)
    }
}

let imageInBase64 = "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"
