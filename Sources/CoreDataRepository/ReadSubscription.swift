// ReadSubscription.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import Combine
import CoreData
import Foundation

final class ReadSubscription<Model: UnmanagedModel> {
    let id: AnyHashable
    private let objectId: NSManagedObjectID
    private let context: NSManagedObjectContext
    let subject: PassthroughSubject<Model, CoreDataRepositoryError>
    private var cancellables: Set<AnyCancellable> = []

    init(
        id: AnyHashable,
        objectId: NSManagedObjectID,
        context: NSManagedObjectContext,
        subject: PassthroughSubject<Model, CoreDataRepositoryError>
    ) {
        self.id = id
        self.subject = subject
        self.objectId = objectId
        self.context = context
    }
}

extension ReadSubscription: SubscriptionProvider {
    func manualFetch() {
        context.perform { [weak self, context, objectId] in
            switch Model.map(from: context.object(with: objectId)) {
            case let .success(unmanaged):
                self?.subject.send(unmanaged)
            case let .failure(error):
                self?.subject.send(completion: .failure(error))
            }
        }
    }

    func cancel() {
        subject.send(completion: .finished)
        cancellables.forEach { $0.cancel() }
    }

    func start() {
        context.perform { [weak self, context, objectId] in
            let object = context.object(with: objectId)
            let startCancellable = object.objectWillChange.sink { [weak self] _ in
                switch Model.map(from: object) {
                case let .success(unmanaged):
                    self?.subject.send(unmanaged)
                case let .failure(error):
                    self?.subject.send(completion: .failure(error))
                }
                
            }
            self?.cancellables.insert(startCancellable)
        }
    }
}
