//
//  ElementQueue.swift
//  Bluefruit
//
//  Created by Antonio García on 17/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

// Command array, executed sequencially
class CommandQueue<Element> {
    let executeHandler: ((_ command: Element) -> Void)?

    private var queueLock = NSLock()

    init(executeHandler: ((_ command: Element) -> Void)?) {
        self.executeHandler = executeHandler
    }

     var queue = [Element]()

    func first() -> Element? {
        queueLock.lock(); defer { queueLock.unlock() }
        //DLog("queue: \(queue) first: \(queue.first)")
        return queue.first
    }

    func executeNext() {
        queueLock.lock()
        guard !queue.isEmpty else { queueLock.unlock(); return }

        //DLog("queue remove finished: \(queue.first)")
        // Delete finished command and trigger next execution if needed
        queue.removeFirst()
        let nextElement = queue.first
        queueLock.unlock()

        if let nextElement = nextElement {
            //DLog("execute next")
            executeHandler?(nextElement)
        }
    }

    func append(_ element: Element) {
        queueLock.lock()
        let shouldExecute = queue.isEmpty
        queue.append(element)
        queueLock.unlock()
        //DLog("queue: \(queue) append: \(element). total: \(queue.count)")

        if shouldExecute {
            executeHandler?(element)
        }
    }

    func removeAll() {
        // DLog("queue removeAll: \(queue.count)")
        queue.removeAll()
    }
}
