//
//  Result+SimpleCheck.swift
//
//  Created by Antonio García on 15/8/21.
//

import Foundation

extension Result {
    var isSuccess: Bool { if case .success = self { return true } else { return false } }
    var isError: Bool { return !isSuccess }
}
