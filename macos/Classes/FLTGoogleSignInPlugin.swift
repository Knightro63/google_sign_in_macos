import FlutterMacOS
import Foundation
import GoogleSignIn

public class FLTGoogleSignInPlugin: NSObject, FlutterPlugin {
  let registry: FlutterTextureRegistry

  
  // The key within `GoogleService-Info.plist` used to hold the application's
  // client id.  See https://developers.google.com/identity/sign-in/ios/start
  // for more info.
  let kClientIdKey:String = "CLIENT_ID";
  let kServerClientIdKey:String = "SERVER_CLIENT_ID"

  // Configuration wrapping Google Cloud Console, Google Apps, OpenID,
  // and other initialization metadata.
  var configuration:GIDConfiguration?

  // Permissions requested during at sign in "init" method call
  // unioned with scopes requested later with incremental authorization
  // "requestScopes" method call.
  // The "email" and "profile" base scopes are always implicitly requested.
  var requestedScopes:[String]?
    
  public static func register(with registrar: FlutterPluginRegistrar) {
      let instance = FLTGoogleSignInPlugin(registrar.textures,GIDSignIn.sharedInstance)
    let method = FlutterMethodChannel(
      name: "plugins.flutter.io/google_sign_in_macos", 
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: method)
  }
    
  init(_ registry: FlutterTextureRegistry, _ signin: GIDSignIn?) {
    self.registry = registry    
    super.init()
    configuration = loadGoogleServiceInfo(signin)
  }
    
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register for GetURL events.
    let appleEventManager = NSAppleEventManager.shared()
    appleEventManager.setEventHandler(
      self,
      andSelector: Selector(("handleGetURLEvent:replyEvent:")),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }
  func handleGetURLEvent(event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
    if let urlString = event?.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue{
      let url = URL(string: urlString)
      GIDSignIn.sharedInstance.handle(url!)
    }
  }

  public func loadGoogleServiceInfo(_ signin: GIDSignIn?) -> GIDConfiguration?{
    let plistPath:String? = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
    if (plistPath != nil) {
      let nsd = NSDictionary(contentsOfFile: plistPath!)
      return GIDConfiguration(
        clientID: nsd![kClientIdKey] as! String,
        serverClientID: nsd![kServerClientIdKey] as? String,
        hostedDomain: nil,
        openIDRealm: nil
      )
    }
    return nil
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "init":
        guard let arguments = call.arguments as? Dictionary<String, AnyObject> else {
          result(FlutterError(code: "ABNORMAL_PARAMETER", message: "no parameters", details: nil))
          return
        }
        print(arguments["clientId"] as? String != nil)
        let config:GIDConfiguration? = (arguments["clientId"] as? String != nil) ? GIDConfiguration(
          clientID: arguments["clientId"] as! String,
          serverClientID: arguments["serverClientId"] as? String,
          hostedDomain: arguments["hostedDomain"] as? String,
          openIDRealm: nil
        ) : configuration;
        
        if (config != nil) {
          let scopes:[String]? = arguments["scopes"] as? [String]
          if(scopes != nil) {
            requestedScopes = scopes;
          }
          configuration = config;
          result(nil);
        } 
        else {
          result(
            FlutterError(
              code: "missing-config",
              message: "GoogleService-Info.plist file not found and clientId was not provided programmatically.",
              details: nil
            )
          )
        }
      case "signInSilently":
        signInSilently(result)
      case "isSignedIn":
        guard GIDSignIn.sharedInstance.currentUser != nil else {
          result(false)
            return
        }
        result(true)
      case "signIn":
        signIn(result)
      case "getTokens":
        getTokens(result)
      case "signOut":
        signOut(result)
      case "disconnect":
        disconnect(result)
      case "requestScopes":
        guard let arguments = call.arguments as? [String:Any],
        let scopes:[String]? = arguments["scopes"] as? [String]? else {
          result("Couldn't find image data")
          return
        }
        requestScopes(result,scopes)
      default:
        result(FlutterMethodNotImplemented)
    }
  }

  func getTokens(_ result: @escaping FlutterResult){
    guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
        result(FlutterError(
          code: "get_tokens",
          message: "No user signed in!",
          details: nil
        ))
        return
    }

      let auth:GIDAuthentication? = currentUser.authentication;
      
      if(auth != nil){
          result([
            "idToken" : auth!.idToken,
            "accessToken" : auth!.accessToken,
          ]);
      }
      else{
          result(FlutterError(
            code: "get_tokens",
            message: "Error getting tokens!",
            details: nil
          ));
      }
      
  }
    func getSignInData(_ user: GIDGoogleUser?) -> [String:Any?]{
        var photoUrl:String?
        if (user!.profile!.hasImage) {
          // Placeholder that will be replaced by on the Dart side based on screen size.
            photoUrl = user!.profile!.imageURL(withDimension: 1337)?.absoluteString
        }
      return [
        "displayName" : user!.profile!.name,
        "email" : user!.profile!.email,
        "id" : user!.userID,
        "photoUrl" : photoUrl,
        "serverAuthCode" : user!.serverAuthCode,
      ]
    }
  /// Signs out the current user.
  func signInSilently(_ result: @escaping FlutterResult) {
    func callbacksign(_ user: GIDGoogleUser?, _ error: Error?){
      if(user != nil){
        result(getSignInData(user))
      }
      else if(error != nil){
        result(FlutterError(
            code: "signin_silently",
            message: "Error signing in silently!",
            details: error!.localizedDescription
          ))
      }
      result(nil)
    }
    GIDSignIn.sharedInstance.restorePreviousSignIn(callback:callbacksign);
  }
  /// Signs out the current user.
  func signOut(_ result: @escaping FlutterResult) {
    GIDSignIn.sharedInstance.signOut()
    result(nil)
  }

  /// Disconnects the previously granted scope and signs the user out.
  func disconnect(_ result: @escaping FlutterResult) {
    GIDSignIn.sharedInstance.disconnect { error in
        if let error:Error = error {
          result(FlutterError(
            code: "disconnect",
            message: "Error disconnecting!",
            details: error.localizedDescription
          ))
      }
      self.signOut(result)
    }
  }
  /// Signs in the user based upon the selected account.'
  /// - note: Successful calls to this will set the `authViewModel`'s `state` property.
  func signIn(_ result: @escaping FlutterResult) {
      if(configuration == nil){
          result(
            FlutterError(
              code: "missing-config",
              message: "GoogleService-Info.plist file not found and clientId was not provided programmatically.",
              details: nil
            )
          )
          return
      }

      guard let presentingWindow = NSApplication.shared.windows.first else {
        result(
          FlutterError(
            code: "google_sign_in",
            message: "There is no root pview controller! ",
            details: nil
          )
        )
        return
      }
      func signingIn(_ user:GIDGoogleUser?,_ error:Error?){
          if(error != nil){
              result(FlutterError(
                  code: "google_sign_in",
                  message: "Sign-in result error!",
                  details: error!.localizedDescription
                ))
          }
          else{
              result(getSignInData(user))
          }
      }
      
      GIDSignIn.sharedInstance.signIn(with: configuration!, presenting: presentingWindow, hint: nil, additionalScopes: nil, callback: signingIn)//requestedScopes
  }

  func requestScopes(_ result: @escaping FlutterResult, _ scopes: [String]?) {
      if(scopes == nil){
          result(FlutterError(
              code: "requestScopes",
              message: "No scopes requested!",
              details: nil
            ))
      }
      
        guard let presentingWindow = NSApplication.shared.windows.first else {
            result(FlutterError(
                code: "requestScopes",
                message: "No presenting window!",
                details: nil
              ))
            return
        }
      func requestingScopes(_ user:GIDGoogleUser?,_ error:Error?){
          if(error != nil){
              result(FlutterError(
                  code: "requestScopes",
                  message: "Found error while adding scope!",
                  details: nil
                ))
          }
          else{
              result(true)
          }
      }
      GIDSignIn.sharedInstance.addScopes(scopes!, presenting: presentingWindow, callback: requestingScopes)
  }
}
