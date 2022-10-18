//
//  NWEndpoint+bonjourName.swift
//  Glider
//
//  Created by Antonio García on 30/8/22.
//

import Network

extension NWEndpoint {
    func bonjourName() -> String? {
        if case let(.service(name, _, _, _)) = self {
            return name
        }
        else {
            return nil
        }
    }
}
