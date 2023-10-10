//
//  Upstream.swift
//  NuguCore
//
//  Created by MinChul Lee on 2020/03/18.
//  Copyright (c) 2019 SK Telecom Co., Ltd. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

import NuguUtils
import NuguObjcUtils

/// An enum that contains the data structures to be send to the server.
public enum Upstream {
    /// A structure that contains a event and contexts.
    public struct Event {
        /// A dictionary that contains payload for the event.
        public let payload: [String: AnyHashable]
        /// A structure that contains header fields for the event.
        public let header: Header
        /// A dictionary that contains extra header fields for the event.
        public let httpHeaderFields: [String: String]?
        /// A array that contains capability interface's context.
        public let contextPayload: [ContextInfo]
        
        /// Creates an instance of an `Event`.
        /// - Parameters:
        ///   - payload: A dictionary that contains payload for the event.
        ///   - header: A structure that contains header fields for the event.
        ///   - httpHeaderFields: A dictionary that contains extra header fields for the event.
        ///   - contextPayload: A array that contains capability interface's context.
        public init(payload: [String: AnyHashable], header: Header, httpHeaderFields: [String: String]? = nil, contextPayload: [ContextInfo]) {
            self.payload = payload
            self.header = header
            self.httpHeaderFields = httpHeaderFields
            self.contextPayload = contextPayload
        }
    }
    
    /// A structure that contains data and headers for the attachment.
    ///
    /// This is sub-data of `Event`
    public struct Attachment {
        /// A structure that contains header fields for the attachment.
        public let header: Header
        /// The sequence number of attachment.
        public let seq: Int32
        /// Indicates whether this attachment is the last one.
        public let isEnd: Bool
        /// The mime type of attachment.
        public let type: String
        /// The binary data.
        public let content: Data
        
        /// Creates an instance of an `Attachment`.
        /// - Parameters:
        ///   - header: A structure that contains header fields for the attachment.
        ///   - seq: The sequence number of attachment.
        ///   - isEnd: Indicates whether this attachment is the last one.
        ///   - type: The mime type of attachment.
        ///   - content: The binary data.
        public init(header: Header, seq: Int32, isEnd: Bool, type: String, content: Data) {
            self.header = header
            self.seq = seq
            self.isEnd = isEnd
            self.type = type
            self.content = content
        }
    }
    
    /// A structure that contains header fields for the event.
    public struct Header: Codable {
        /// The namespace of event.
        public let namespace: String
        /// The name of event.
        public let name: String
        // The version of the functional interface for which the event is defined.
        /// The version of capability interface that .
        public let version: String
        /// The identifier for the request that generated by client.
        public let dialogRequestId: String
        /// The unique identifier for the event.
        public let messageId: String
        /// The referrer dialog request identifier.
        public let referrerDialogRequestId: String?
        
        /// Creates an instance of an `Header`.
        /// - Parameters:
        ///   - namespace: The namespace of event.
        ///   - name: The name of event.
        ///   - version: The version of capability interface.
        ///   - dialogRequestId: The identifier for the request that generated by client.
        ///   - messageId: The identifier for the request that generated by client.
        ///   - referrerDialogRequestId: The referrer dialog request identifier.
        public init(namespace: String, name: String, version: String, dialogRequestId: String, messageId: String, referrerDialogRequestId: String? = nil) {
            self.namespace = namespace
            self.name = name
            self.version = version
            self.dialogRequestId = dialogRequestId
            self.messageId = messageId
            self.referrerDialogRequestId = referrerDialogRequestId
        }
    }
}

// MARK: - Upstream.Event

extension Upstream.Event {
    var headerString: String {
        guard let data = try? JSONEncoder().encode(header),
            let jsonString = String(data: data, encoding: .utf8) else {
                return ""
        }
        
        return jsonString
    }
    
    var payloadString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let payloadString = String(data: data, encoding: .utf8) else {
                return ""
        }
        
        return payloadString
    }
    
    var contextString: String {
        let contextDictionary = Dictionary(grouping: contextPayload, by: { $0.contextType })
        let supportedInterfaces = contextDictionary[.capability]?.reduce(
            into: [String: AnyHashable]()
        ) { result, context in
            result[context.name] = context.payload
        }
        var client: [String: AnyHashable] = ["os": "iOS"]
        contextDictionary[.client]?.forEach({ (contextInfo) in
            client[contextInfo.name] = contextInfo.payload
        })
        
        let contextDict: [String: AnyHashable] = [
            "supportedInterfaces": supportedInterfaces,
            "client": client
        ]
        
        var contextString: String = ""
        if let error = UnifiedErrorCatcher.try ({
            do {
                let data = try JSONSerialization.data(withJSONObject: contextDict.compactMapValues { $0 }, options: [])
                contextString = String(data: data, encoding: .utf8) ?? ""
            } catch {
                return error
            }
            
            return nil
        }) {
            log.error("context dictionary includes unserializable object. error: \(error)")
        }
        
        return contextString
    }
}

// MARK: - Upstream.Event.Header

extension Upstream.Header {
    /// The type of event.
    public var type: String { "\(namespace).\(name)" }
}

// MARK: - Upstream.Attachment + CustomStringConvertible

/// :nodoc:
extension Upstream.Attachment: CustomStringConvertible {
    public var description: String {
        return "\(header))"
    }
}
