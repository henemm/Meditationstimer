//
//  HeartRateStream.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 02.09.25.
//

import Foundation
import HealthKit
import Combine

class HeartRateStream: ObservableObject {
    @Published var samples: [HKQuantitySample] = []
    private var healthStore: HKHealthStore
    private var query: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private var isStreaming = false
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    func start(from startDate: Date) {
        guard !isStreaming else { return }
        isStreaming = true
        samples = []
        anchor = nil
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] _, newSamples, _, newAnchor, _ in
            guard let self = self else { return }
            if let newSamples = newSamples as? [HKQuantitySample] {
                DispatchQueue.main.async {
                    self.samples.append(contentsOf: newSamples)
                }
            }
            self.anchor = newAnchor
        }
        query.updateHandler = { [weak self] _, newSamples, _, newAnchor, _ in
            guard let self = self else { return }
            if let newSamples = newSamples as? [HKQuantitySample] {
                DispatchQueue.main.async {
                    self.samples.append(contentsOf: newSamples)
                }
            }
            self.anchor = newAnchor
        }
        self.query = query
        healthStore.execute(query)
    }
    
    func stop() {
        guard isStreaming, let query = query else { return }
        healthStore.stop(query)
        self.query = nil
        isStreaming = false
    }
    
    struct Summary {
        let min: Double?
        let avg: Double?
        let max: Double?
    }
    
    func summary() -> Summary {
        let values = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) }
        guard !values.isEmpty else {
            return Summary(min: nil, avg: nil, max: nil)
        }
        let minVal = values.min()
        let maxVal = values.max()
        let avgVal = values.reduce(0, +) / Double(values.count)
        return Summary(min: minVal, avg: avgVal, max: maxVal)
    }
}

