import Capacitor
import Security

@objc(NotepadCredentialsPlugin)
public class NotepadCredentialsPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier="NotepadCredentialsPlugin"
    public let jsName="NotepadCredentials"
    public let pluginMethods:[CAPPluginMethod]=[CAPPluginMethod(name:"get",returnType:CAPPluginReturnPromise),CAPPluginMethod(name:"set",returnType:CAPPluginReturnPromise),CAPPluginMethod(name:"remove",returnType:CAPPluginReturnPromise)]
    private var query:[String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:(Bundle.main.bundleIdentifier ?? "NotepadMobile")+".github",kSecAttrAccount as String:"account"] }
    @objc func get(_ call:CAPPluginCall) {
        var q=query;q[kSecReturnData as String]=true;q[kSecMatchLimit as String]=kSecMatchLimitOne;var result:CFTypeRef?
        let status=SecItemCopyMatching(q as CFDictionary,&result)
        if status==errSecItemNotFound { call.resolve(["value":NSNull()]);return }
        guard status==errSecSuccess,let data=result as? Data,data.count<=16384,let value=String(data:data,encoding:.utf8) else { call.reject("Secure storage unavailable","secure_storage");return };call.resolve(["value":value])
    }
    @objc func set(_ call:CAPPluginCall) {
        guard let value=call.getString("value"),let data=value.data(using:.utf8),data.count<=16384 else { call.reject("Invalid credentials","secure_storage");return }
        let attributes=[kSecValueData as String:data,kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as [String:Any]
        var status=SecItemUpdate(query as CFDictionary,attributes as CFDictionary)
        if status==errSecItemNotFound { var q=query;attributes.forEach{q[$0.key]=$0.value};status=SecItemAdd(q as CFDictionary,nil) }
        if status==errSecSuccess { call.resolve() } else { call.reject("Secure storage unavailable","secure_storage") }
    }
    @objc func remove(_ call:CAPPluginCall) {
        let status=SecItemDelete(query as CFDictionary);if status==errSecSuccess||status==errSecItemNotFound { call.resolve() } else { call.reject("Secure storage unavailable","secure_storage") }
    }
}
@objc(NotepadViewController)
class NotepadViewController: CAPBridgeViewController {
    override func capacitorDidLoad() { bridge?.registerPluginInstance(NotepadCredentialsPlugin()) }
}
