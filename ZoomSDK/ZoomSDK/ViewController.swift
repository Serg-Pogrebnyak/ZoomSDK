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
    
    let userIdentifier = "gvyuh78yiu1"
    
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
    
    fileprivate func startScaninng() {
        let customization: ZoomCustomization = ZoomCustomization()
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
        return false
    }
    
    func onZoomVerificationResult(result: ZoomVerificationResult) {
        print("get result")
        guard result.status.rawValue == 0 else {
            print("error scanning")
            return
        }
        registerNewUser(result: result)
    }
    
    // MARK: - register new user
    fileprivate func registerNewUser(result: ZoomVerificationResult) {
        let zoomFacemapStr: String = (result.faceMetrics?.zoomFacemap)!.base64EncodedString(options: [])
        let endpoint = "/enrollment"
        var parameters: [String : Any] = [String: Any]()
        
        parameters["sessionId"] = result.sessionId
        parameters["enrollmentIdentifier"] = userIdentifier
        parameters["facemap"] = zoomFacemapStr
        
        makeApiCall(method: .post, endpoint: endpoint, parameters: parameters) { (isJson) in
            guard let json = isJson else {
                print("error register user")
                return
            }
            if (json["data"] as? [String : Any])?["livenessResult"] as? String == "passed" {
                print("User create")
                self.sendImageOnServer()
            } else {
                print("User NO Created some error!")
            }
        }
    }
    
    // MARK: - delete user
    fileprivate func deleteUserEnrollment(callback: @escaping (Bool) -> Void ) {
        let endpoint: String = "/enrollment/\(userIdentifier)"
        var parameters: [String : Any] = [:]
        parameters["enrollmentIdentifier"] = userIdentifier
        
        makeApiCall(method: .delete, endpoint: endpoint, parameters: parameters) { (isJson) in
            guard let json = isJson else {
                print("error deleating user")
                return
            }
            
            callback(((json["meta"] as? [String : Any])?["ok"] as? Bool)!)
            print("user is deleate - \(((json["meta"] as? [String : Any])?["ok"] as? Bool)!)")
        }
        
    }
    
    // MARK: - authentication user
    fileprivate func authenticationUser(imageInBase64: String) {
        let endpoint = "/authenticate"
        var parameters: [String : Any] = [String: Any]()
        
        parameters["sessionId"] = generateUniqueSessionId()
        parameters["source"] = ["enrollmentIdentifier": userIdentifier]
        parameters["targets"] = [["facemap": imageInBase64]]
        
        makeApiCall(method: .post, endpoint: endpoint, parameters: parameters) { (isJson) in
            guard let json = isJson else {
                print("error authentication user")
                return
            }
            
            if ((json["data"] as? [String : Any])?["results"] as? [[String : AnyObject]])?[0]["authenticated"] as? Int == 1 {
                print("User was authorization")
            } else {
                print("User not enrolled or invalid enrollmentIdentifier")
            }
        }
    }
    
    // MARK: - create facemap user from image
    fileprivate func sendImageOnServer() {
        
        let endpoint: String = "/facemap"
        var parameters: [String : Any] = [:]
        let imageData: Data = UIImage.init(named: "sergFace")!.jpegData(compressionQuality: 1.0)!
        
        parameters["images"] = [imageData.base64EncodedString()]
        parameters["sessionId"] = generateUniqueSessionId()
        makeApiCall(method: .post, endpoint: endpoint, parameters: parameters) { (isJson) in
            guard let json = isJson else {
                print("error create face-map user")
                return
            }
            
            if json["data"] != nil {
                self.authenticationUser(imageInBase64: json["data"] as! String) //todo - add validation on is string
                print("Successfull create face map")
            } else {
                print("erro creating face map")
            }
        }
    }
    
    // MARK: - check user id
    func isUserEnrolled(callback: @escaping (Bool) -> Void) {
        
        let endpoint: String = "/enrollment/\(userIdentifier)"
        var parameters: [String : Any] = [:]
        parameters["enrollmentIdentifier"] = userIdentifier
        parameters["sessionId"] = generateUniqueSessionId()
        
        makeApiCall(method: .get, endpoint: endpoint, parameters: parameters) { (isJson) in
            guard let json = isJson else {
                print("error cehck user")
                return
            }
            print("enrolled: \(((json["meta"] as? [String : Any])?["ok"] as? Bool)!)")
            callback(((json["meta"] as? [String : Any])?["ok"] as? Bool)!)
        }
    }
    
    // MARK: - generate session id
    func generateUniqueSessionId() -> String {
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

    // MARK: Create and make api call
    fileprivate func makeApiCall(method: ApiMethod, endpoint: String, parameters: [String: Any], callback: @escaping ([String: AnyObject]?) -> Void) {
        let request = buildHTTPRequest(method: method, endpoint: endpoint, parameters: parameters)
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { responseData, response, error in
            
            guard let responseData = responseData , error == nil else {
                callback(nil)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject]
                callback(json)
            }
            catch {
                callback(nil)
            }
        })
        task.resume()
    }
    
    fileprivate func buildHTTPRequest(method: ApiMethod, endpoint: String, parameters: [String : Any]) -> NSMutableURLRequest {
        let request = NSMutableURLRequest(url: NSURL(string: zoomServerBaseURL + endpoint)! as URL)
        request.httpMethod = method.rawValue
        // Only send data if there are parameters and this is not a GET request
        if parameters.count > 0 && method != ApiMethod.get {
            request.httpBody = try! JSONSerialization.data(withJSONObject: parameters as Any, options: JSONSerialization.WritingOptions(rawValue: 0))
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(licenseKey, forHTTPHeaderField: "X-App-Token")
        let sessionId: String = parameters["sessionId"] as? String ?? "nil"
        request.addValue("facetec|zoomsdk|ios|\(Bundle.main.bundleIdentifier!)|\(licenseKey)|\(UIDevice.current.zoomDeviceIdentifierForVendor)|\(UIDevice.current.modelName)|\(Zoom.sdk.version)|\(Locale.current.identifier)|\(Bundle.main.preferredLocalizations.first ?? "Unknown")|\(sessionId)",
            forHTTPHeaderField: "User-Agent")
        
        return request
    }
    
    enum ApiMethod: String {
        case post = "POST"
        case get = "GET"
        case delete = "DELETE"
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
