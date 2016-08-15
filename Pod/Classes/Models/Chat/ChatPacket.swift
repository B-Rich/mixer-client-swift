//
//  ChatPacket.swift
//  Beam API
//
//  Created by Jack Cook on 6/4/15.
//  Copyright (c) 2016 Beam Interactive, Inc. All rights reserved.
//

import SwiftyJSON

/// The base packet class. Also has methods used to receive and send packets.
public class ChatPacket {
    
    /// The string of the packet's raw data.
    private var packetString: String?
    
    /**
     Creates a raw packet string from a packet object.
     
     :param: packet The packet being sent by the app.
     :param: count The nth packet sent by the app.
     :returns: The raw packet string to be sent to the chat servers.
     */
    class func prepareToSend(packet: ChatSendable, count: Int) -> String {
        let method = packet.identifier
        let arguments = packet.arguments()
        
        var argumentString = ""
        
        for arg in arguments {
            if arg is String {
                argumentString += "\"\(arg)\","
            } else {
                argumentString += "\(arg),"
            }
        }
        
        argumentString = argumentString.substringToIndex(argumentString.endIndex.predecessor())
        
        let packetString = "{\"type\":\"method\",\"method\":\"\(method)\",\"arguments\":[\(argumentString)],\"id\":\(count)}"
        
        return packetString
    }
    
    /**
     Interprets JSON packets received from the chat servers.
     
     :param: json The JSON object being interpreted.
     :returns: The packet object to be used by the app.
     */
    class func receivePacket(json: JSON) -> ChatPacket? {
        var packet: ChatPacket?
        
        if let event = json["event"].string {
            if let data = json["data"].dictionaryObject {
                switch event {
                case "ChatMessage":
                    let message = BeamMessage(json: JSON(data))
                    packet = ChatMessagePacket(message: message)
                case "DeleteMessage":
                    if let id = data["id"] as? String {
                        packet = ChatDeleteMessagePacket(id: id)
                    }
                case "PollEnd":
                    if let voters = data["voters"] as? Int {
                        if let responses = data["responses"] as? [String: Int] {
                            packet = ChatPollEndPacket(voters: voters, responses: responses)
                        }
                    }
                case "PollStart":
                    if let answers = data["answers"] as? [String] {
                        if let question = data["q"] as? String {
                            if let endTime = data["endsAt"] as? Int {
                                if let duration = data["duration"] as? Int {
                                    let endDate = NSDate(timeIntervalSinceReferenceDate: NSTimeInterval(endTime))
                                    packet = ChatPollStartPacket(answers: answers, question: question, endTime: endDate, duration: duration)
                                }
                            }
                        }
                    }
                case "UserJoin", "UserLeave":
                    if let username = data["username"] as? String {
                        if let roles = data["roles"] as? [String] {
                            if let userId = data["id"] as? Int {
                                if event == "UserJoin" {
                                    packet = ChatUserJoinPacket(username: username, roles: roles, userId: userId)
                                } else if event == "UserLeave" {
                                    packet = ChatUserLeavePacket(username: username, roles: roles, userId: userId)
                                }
                            }
                        }
                    }
                case "UserUpdate":
                    if let permissions = data["permissions"] as? [String] {
                        if let userId = data["user"] as? Int {
                            if let username = data["username"] as? String {
                                if let roles = data["roles"] as? [String] {
                                    packet = ChatUserUpdatePacket(permissions: permissions, userId: userId, username: username, roles: roles)
                                }
                            }
                        }
                    }
                default:
                    print("Unrecognized packet received: \(event) with parameters \(data)")
                }
            }
        } else if let type = json["type"].string {
            switch type {
            case "reply":
                if let data = json["data"].arrayObject {
                    var packets = [ChatMessagePacket]()
                    for datum in data {
                        let message = BeamMessage(json: JSON(datum))
                        let messagePacket = ChatMessagePacket(message: message)
                        packets.append(messagePacket)
                    }
                    
                    let packet = ChatMessagesPacket(packets: packets)
                    return packet
                }
            default:
                print("Unknown packet received: \(json)")
            }
        } else {
            print("Unknown packet received: \(json)")
        }
        
        return packet
    }
}