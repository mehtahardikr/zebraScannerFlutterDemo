import UIKit
import Flutter


enum Channels {
    
    static let CHANNEL  = "com.hm.zebra/scanner"
    static let EVENT_CHANNEL = "com.hm.zebra/scannerEvents"
    static let EVENT_CHANNEL_BARCODE = "com.hm.zebra/barcodeEvents"
    
}

enum Events {
 
    static let EVENT_INIT = "init"
    static let EVENT_PAIR = "pair"
    static let EVENT_TEST_BEEP = "testBeep"
    static let EVENT_DISCONNECT = "disconnect"
    static let EVENT_GET_LIST = "getList"
    static let EVENT_ACTIVE_SCANNER_LIST = "getActiveScannerList"
  
}


private var eventSinkScanner: FlutterEventSink?
private var eventSinkBarcode: FlutterEventSink?
private var mScannerInfoList :  NSMutableArray? = NSMutableArray()
private var apiInstance : ISbtSdkApi?
private var showAlert : CustomAlert?


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, ISbtSdkApiDelegate, CustomAlertDelegate {
    func cancelButtonPressed(_ alert: CustomAlert, alertTag: Int) {
        print("Cancel button pressed")
    }
    
    func sbtEventBarcode(_ barcodeData: String!, barcodeType: Int32, fromScanner scannerID: Int32) {
        
    }
    
    func sbtEventFirmwareUpdate(_ fwUpdateEventObj: FirmwareUpdateEvent!) {
        
    }
    
    func sbtEventImage(_ imageData: Data!, fromScanner scannerID: Int32) {
        
    }
    
    func sbtEventVideo(_ videoFrame: Data!, fromScanner scannerID: Int32) {
        
    }
    
    
    func sbtEventScannerAppeared(_ availableScanner: SbtScannerInfo!) {
        
        if((showAlert?.isBeingPresented ) != nil){
            showAlert?.dismiss(animated: false)
        }
        
        let data = ScannerData(id : String(availableScanner.getScannerID()) ,
                               name : availableScanner.getScannerName() ,
                               event :  "appeared",
                               active :  availableScanner.isActive())
        
        eventSinkScanner?(convertToJsonString(data: data))
        mScannerInfoList?.removeAllObjects()
        mScannerInfoList?.add(availableScanner)
        
    }
    func sbtEventScannerDisappeared(_ scannerID: Int32) {
        
        eventSinkScanner?(FlutterError(code: "400", message: "device disappeared", details:String(scannerID)))

    }
    
    func sbtEventCommunicationSessionEstablished(_ activeScanner: SbtScannerInfo!) {
        
        if((showAlert?.isBeingPresented ) != nil){
            showAlert?.dismiss(animated: false)
        }
        
        let data = ScannerData(id : String(activeScanner.getScannerID()) ,
                               name : activeScanner.getScannerName() ,
                               event :  "connected",
                               active :  activeScanner.isActive())
        
        eventSinkScanner?(convertToJsonString(data: data))
        
    }
    func sbtEventCommunicationSessionTerminated(_ scannerID: Int32) {
        
    }
    
    func sbtEventBarcodeData(_ barcodeData: Data!, barcodeType: Int32, fromScanner scannerID: Int32) {
        
        
        if let value = String(data: barcodeData, encoding: .utf8) {
            print(value)
            eventSinkBarcode?(value)
        } else {
            print("not a valid UTF-8 sequence")
        }
        
    }
    
    

    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
     
      FlutterMethodChannel(name : Channels.CHANNEL,binaryMessenger :
                                                controller.binaryMessenger).setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          if call.method == Events.EVENT_PAIR {
              self.showPairAlert()
          }else if call.method == Events.EVENT_DISCONNECT{
              
              guard let result = call.arguments else {
                                return
                            }
                            let myresult = result as? [String: Any]
                            let deviceId = myresult?["deviceId"] as? String
              
              self.disconnectDevice(scannerId: deviceId!)
              
          }else if call.method == Events.EVENT_TEST_BEEP {
              guard let result = call.arguments else {
                                return
                            }
                            let myresult = result as? [String: Any]
                            let deviceId = myresult?["deviceId"] as? String
              
              self.testBeep(scannerId : deviceId!)
              
          }else if call.method == Events.EVENT_ACTIVE_SCANNER_LIST {
              self.getActiveScannersList()
          }else if call.method == Events.EVENT_INIT {
              self.initComponents()
          }
     })
      
      FlutterEventChannel(name: Channels.EVENT_CHANNEL, binaryMessenger: controller.binaryMessenger).setStreamHandler(ScannerStreamHandler())
      
      FlutterEventChannel(name: Channels.EVENT_CHANNEL_BARCODE, binaryMessenger: controller.binaryMessenger).setStreamHandler(BarcodeStreamHandler())
      
    
      
    

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    // init components
    func initComponents(){
            
           if(apiInstance != nil){ return}
            // Get instance to the Zebra Scanner SDK API
            apiInstance = SbtSdkFactory.createSbtSdkApiInstance()
            apiInstance?.sbtSetDelegate(self)
            apiInstance?.sbtSetOperationalMode(Int32(SBT_OPMODE_ALL))
            
            var notifications_mask = 0
            /// scanner appear /disappear
            
            notifications_mask |= (SBT_EVENT_SCANNER_APPEARANCE | SBT_EVENT_SCANNER_DISAPPEARANCE)
            
            /// connection establishment/ terminate
            
            notifications_mask |= (SBT_EVENT_SESSION_ESTABLISHMENT | SBT_EVENT_SESSION_TERMINATION)
            
            /// listen for barcode scan
            
            notifications_mask |= SBT_EVENT_BARCODE
            
            /// subscribe for notifications
            apiInstance?.sbtSubsribe(forEvents: Int32(notifications_mask))
            apiInstance?.sbtEnableAvailableScannersDetection(true)
            
            
        
        }
    
    
    
    
    
    /// show pair device dialog
    
    func showPairAlert() {
        
    
        if (apiInstance == nil)  { return }
        
        let sizeRect = UIScreen.main.bounds
        
        let imageView = UIImageView(frame: CGRect(x: 10, y: 100, width: sizeRect.width, height: 120))
        let barcode = apiInstance?.sbtGetPairingBarcode(BARCODE_TYPE_STC, withComProtocol:STC_SSI_BLE  , withSetDefaultStatus: SETDEFAULT_NO, withImageFrame: imageView.frame)
        //imageView.image = barcode
        
        
        showAlert = CustomAlert()
        showAlert?.alertTitle = "Scan below QR to pair the scanner"
        showAlert?.alertTag = 1
        showAlert?.cancelButtonTitle = "Cancel"
        showAlert?.statusImage = barcode
        showAlert?.delegate = self
        showAlert?.show()
        
       /* showAlert = UIAlertController(title: "Scan below QR to pair the scanner", message: nil, preferredStyle: .alert)
               
           let imageView = UIImageView(frame: CGRect(x: 20, y: 80, width: 300, height: 100))
               
            let barcode = apiInstance?.sbtGetPairingBarcode(BARCODE_TYPE_STC, withComProtocol:STC_SSI_BLE  , withSetDefaultStatus: SETDEFAULT_NO, withImageFrame: imageView.frame)
            
               imageView.image = barcode // Your image here...
               showAlert?.view.addSubview(imageView)
        
        let height = NSLayoutConstraint(item: showAlert?.view! as Any, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: imageView.frame.height)
               
        
        let width = NSLayoutConstraint(item: showAlert?.view! as Any, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant:imageView.frame.width)
        
               showAlert?.view.addConstraint(height)
              showAlert?.view.addConstraint(width)
        
        
               showAlert?.addAction(UIAlertAction(title: "CLOSE", style: .default, handler: { action in
                   showAlert?.dismiss(animated: true)
               }))
               self.window?.rootViewController?.present(showAlert!, animated: true, completion: nil) */
    }
    
    /// disconnect scanner
    func disconnectDevice(scannerId : String) {
        if (apiInstance == nil)  { return }
        var result: SBT_RESULT? = apiInstance?.sbtTerminateCommunicationSession(Int32(scannerId) ?? 0)
        
        if(result == SBT_RESULT_SUCCESS){
         
            let data = ScannerData(id : scannerId ,
                                   name : "" ,
                                   event :  "disconnected",
                                   active :  true)
            
            eventSinkScanner?(convertToJsonString(data: data))
            
        } else if (result == SBT_RESULT_FAILURE) {
            
            eventSinkScanner?(FlutterError(code: "400", message: "disconnect event failed", details:"command failed"))
        }
    }
    
    /// test beep
    func testBeep (scannerId : String) {
        if (apiInstance == nil)  { return }
        
        let inXML = "<inArgs><scannerID>\(scannerId)</scannerID><cmdArgs><arg-int>\(Int32(SBT_BEEPCODE_MIX3_HIGH_LOW_HIGH))</arg-int></cmdArgs></inArgs>"
        
        var result: SBT_RESULT? = apiInstance?.sbtExecuteCommand(Int32(SBT_SET_ACTION), aInXML: inXML, aOutXML: nil, forScanner: Int32(scannerId) ?? 0)
        
        if(result == SBT_RESULT_SUCCESS){
            
            let data = ScannerData(id : scannerId ,
                                   name : "" ,
                                   event :  "beeped",
                                   active :  true)
            
            eventSinkScanner?(convertToJsonString(data: data))
            
            
        }else if(result == SBT_RESULT_FAILURE) {
            eventSinkScanner?(FlutterError(code: "400", message: "Event passed failed", details:"command failed"))
        }
    }
    
    /// get Active scanners list
    func getActiveScannersList(){
        if (apiInstance == nil)  { return }
        apiInstance?.sbtGetActiveScannersList(&mScannerInfoList)

        var list : [ScannerData]? = [ScannerData]()
        
        
        if let _scanners = mScannerInfoList {
                    for scanner in _scanners {
                        if let scanner = scanner as? SbtScannerInfo {
                            list?.append(ScannerData(id: String(scanner.getScannerID()),
                                                    name: scanner.getScannerName(), event:"N/A", active: scanner.isActive()))
                        }
                    }
                }

        print(convertListIntoJSON(listOfScanners: list!))
        eventSinkScanner?(convertListIntoJSON(listOfScanners: list!))
    }
    
    
}





/**
       Stream handler for scanner events
 */
class ScannerStreamHandler : NSObject , FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSinkScanner = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSinkScanner = nil
        return nil
    }
    
}

/**
       Stream handler for barcode events
 */

class BarcodeStreamHandler : NSObject , FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSinkBarcode = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSinkBarcode = nil
        return nil
    }
    
}



/**
    Scanner Data
 */

class ScannerData :  Codable{
    var name:String
    var id:String
    var active: Bool
    var event:String
    
    init(id: String, name: String,  event: String, active: Bool) {
        self.name = name
        self.id = id
        self.active = active
        self.event = event
    }
}

/**
   convert object to json string
 */
func convertToJsonString(data: ScannerData ) -> String   {
    
    let jsonEncoder = JSONEncoder()
    let jsonData = try! jsonEncoder.encode(data)
    guard let json = String(data: jsonData, encoding: String.Encoding.utf8) else { return  "" }
    return json
}

/// convert custom list to JSON string
func convertListIntoJSON(listOfScanners: [ScannerData]) -> String? {
    guard let data = try? JSONEncoder().encode(listOfScanners) else { return nil }
    return String(data: data, encoding: String.Encoding.utf8)
}


