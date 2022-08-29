// CoreDataRepository+CRUD.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import Combine
import CoreData

extension CoreDataRepository {
    // MARK: Functions/Endpoints

    /// Create an instance of a NSManagedObject sub class from a corresponding value type.
    /// Supports specifying a transactionAuthor that is applied to the context before saving.
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     -   _ item: Model
    ///     - transactionAuthor: String? = nil
    /// - Returns
    ///     - Result<Model, CoreDataRepositoryError>
    ///
    public func create<Model: UnmanagedModel>(_ item: Model, transactionAuthor: String? = nil) async -> Result<Model, CoreDataRepositoryError> {
        await context.performInScratchPad(schedule: .enqueued) { scratchPad in
            scratchPad.transactionAuthor = transactionAuthor
            let object = NSManagedObject(entity: Model.managedEntityDesc, insertInto: scratchPad)
            try item.create(managed: object)
            let newItem = try Model.tryMap(from: object)
            try scratchPad.save()
            return newItem
        }
    }

    /// Read an instance of a NSManagedObject sub class as a corresponding value type
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     -   _ objectID: NSManagedObjectID
    /// - Returns
    ///     - Result<Model, CoreDataRepositoryError>
    ///
    public func read<Model: UnmanagedModel>(_ url: URL) async -> Result<Model, CoreDataRepositoryError> {
        await context.performInChild(schedule: .enqueued) { readContext in
            let id = try readContext.tryObjectId(from: url)
            let object = try readContext.notDeletedObject(for: id)
            return try Model.tryMap(from: object)
        }
    }

    /// Update an instance of a NSManagedObject sub class from a corresponding value type.
    /// Supports specifying a transactionAuthor that is applied to the context before saving.
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     - objectID: NSManagedObjectID
    ///     - with  item: Model
    ///     - transactionAuthor: String? = nil
    /// - Returns
    ///     - Result<Model, CoreDataRepositoryError>
    ///
    public func update<Model: UnmanagedModel>(
        _ url: URL,
        with item: Model,
        transactionAuthor: String? = nil
    ) async -> Result<Model, CoreDataRepositoryError> {
        await context.performInScratchPad(schedule: .enqueued) { scratchPad in
            let id = try scratchPad.tryObjectId(from: url)
            let object = try scratchPad.notDeletedObject(for: id)
            try item.update(managed: object)
            let updatedItem: Model = try Model.tryMap(from: object)
            try scratchPad.save()
            return updatedItem
        }
    }

    /// Delete an instance of a NSManagedObject sub class. Supports specifying a
    /// transactionAuthor that is applied to the context before saving.
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     - objectID: NSManagedObjectID
    ///     - transactionAuthor: String? = nil
    /// - Returns
    ///     - Result<Void, CoreDataRepositoryError>
    ///
    public func delete(
        _ url: URL,
        transactionAuthor: String? = nil
    ) async -> Result<Void, CoreDataRepositoryError> {
        await context.performInScratchPad(schedule: .enqueued) { scratchPad in
            let id = try scratchPad.tryObjectId(from: url)
            let object = try scratchPad.notDeletedObject(for: id)
            object.prepareForDeletion()
            scratchPad.delete(object)
            try scratchPad.save()
            return ()
        }
    }

    /// Subscribe to updates for an instance of a NSManagedObject subclass.
    /// - Parameter publisher: Pub<Model, Error>
    /// - Returns: AnyPublisher<Model, CoreDataRepositoryError>
    public func readSubscription<Model: UnmanagedModel>(_ url: URL) -> AnyPublisher<Model, CoreDataRepositoryError> {
        let readContext = context.childContext()
        let readPublisher: AnyPublisher<NSManagedObject, CoreDataRepositoryError> = readManaged(url, readContext: readContext)
        var subjectCancellable: AnyCancellable?
        return Publishers.Create<Model, CoreDataRepositoryError> { [weak self] subscriber in
            let subject = PassthroughSubject<Model, CoreDataRepositoryError>()
            subjectCancellable = subject.sink(receiveCompletion: subscriber.send, receiveValue: subscriber.send)

            let id = UUID()
            var subscription: SubscriptionProvider?
            self?.cancellables.insert(readPublisher.sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        subject.send(completion: completion)
                    }
                },
                receiveValue: { repoManaged in
                    let subscriptionProvider = ReadSubscription(
                        id: id,
                        objectId: repoManaged.objectID,
                        context: readContext,
                        subject: subject
                    )
                    subscription = subscriptionProvider
                    subscriptionProvider.start()
                    if let _self = self,
                       let _subjectCancellable = subjectCancellable
                    {
                        _self.subscriptions.append(subscriptionProvider)
                        _self.cancellables.insert(_subjectCancellable)
                    } else {
                        subjectCancellable?.cancel()
                        subscription?.cancel()
                    }
                    subscriptionProvider.manualFetch()
                }
            ))
            return AnyCancellable {
                subscription?.cancel()
                self?.subscriptions.removeAll(where: { $0.id == id as AnyHashable })
            }
        }.eraseToAnyPublisher()
    }

    private static func getObjectId(
        fromUrl url: URL,
        context: NSManagedObjectContext
    ) -> Result<NSManagedObjectID, CoreDataRepositoryError> {
        guard let objectId = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            return Result.failure(.failedToGetObjectIdFromUrl(url))
        }
        return .success(objectId)
    }

    private func readManaged(
        _ url: URL,
        readContext: NSManagedObjectContext
    ) -> AnyPublisher<NSManagedObject, CoreDataRepositoryError> {
        Future { promise in
            readContext.performAndWait {
                let result: Result<NSManagedObject, CoreDataRepositoryError> = readContext.objectId(from: url)
                    .mapToNSManagedObject(context: readContext)
                    .mapToRepoError()
                promise(result)
            }
        }.eraseToAnyPublisher()
    }
}
