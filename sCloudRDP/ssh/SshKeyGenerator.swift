//
//  SshKeyGenerator.swift
//  sCloudRDP
//
//  Created by Iordan Iordanov on 2024-11-13.
//  Copyright © 2024 iordan iordanov. All rights reserved.
//

import Foundation
import CryptoKit

class SshKeyGenerator {
    
    /**
     Generates a private key
     Refer to https://developer.apple.com/documentation/security/item-attribute-keys-and-values for valid type value
     */
    func generatePrivateKey(type: CFString, bits: Int) -> SecKey? {
        let tag = UIApplication.appId!.data(using: .utf8)!
        let attributes: [String: Any] =
        [
            kSecAttrKeyType as String: type,
            kSecAttrKeySizeInBits as String: bits,
            kSecPrivateKeyAttrs as String:
                [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tag
                ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            log_callback_str(message: "Error '\(String(describing: error))' generating key of type \(type) with bits \(bits)")
            return nil
        }
        
        return privateKey
    }
    
    func getPublicKey(privateKey: SecKey) -> SecKey {
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        return publicKey
    }
    
    func privateKeytoBase64String(privateKey: SecKey) -> String? {
        var error:Unmanaged<CFError>?
        guard let cfdata = SecKeyCopyExternalRepresentation(privateKey, &error) else {
            return nil
        }
        
        let data: Data = cfdata as Data
        do {
            let pKey = try P521.Signing.PrivateKey(x963Representation: data)
            let key: String? =
            if #available(iOS 14.0, *) {
                pKey.pemRepresentation
            } else {
                nil
            }
            return key
        } catch {
            return nil
        }
    }
    
    func publicKeytoBase64String(publicKey: SecKey) -> String? {
        var error: Unmanaged<CFError>?
        guard let cfdata = SecKeyCopyExternalRepresentation(publicKey, &error) else { return nil }
        let data: Data = cfdata as Data
        do {
            let pKey = try P521.Signing.PublicKey(x963Representation: data)
            let key: String? =
            if #available(iOS 14.0, *) {
                pKey.pemRepresentation
            } else {
                nil
            }
            return key
        } catch {
            return nil
        }
    }
}
