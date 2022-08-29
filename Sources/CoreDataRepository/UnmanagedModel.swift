// UnmanagedModel.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import CoreData
import Foundation

/// A protocol for a value type that corresponds to a RepositoryManagedModel
public protocol UnmanagedModel: Equatable {
    static var managedEntityDesc: NSEntityDescription { get }
    /// Keep an reference to the corresponding `RepositoryManagedModel` instance for getting it later.
    /// Optional since a new instance won't have a record in CoreData.
    var managedRepoUrl: URL? { get set }
    /// Returns a NSManagedObject instance of `self`
    func asManaged(in context: NSManagedObjectContext) -> NSManagedObject

    func create(managed: NSManagedObject) throws

    func update(managed: NSManagedObject) throws

    static func tryMap(from object: NSManagedObject) throws -> Self

    static func map(from object: NSManagedObject) -> Result<Self, CoreDataRepositoryError>

    static func tryMapMany(from objects: [NSManagedObject]) throws -> [Self]

    static func mapMany(from objects: [NSManagedObject]) -> Result<[Self], CoreDataRepositoryError>
}

extension UnmanagedModel {
    public static func map(from object: NSManagedObject) -> Result<Self, CoreDataRepositoryError> {
        Result {
            try tryMap(from: object)
        }
        .mapToRepoError()
    }

    public static func mapMany(from objects: [NSManagedObject]) -> Result<[Self], CoreDataRepositoryError> {
        Result {
            try tryMapMany(from: objects)
        }
        .mapToRepoError()
    }
}
