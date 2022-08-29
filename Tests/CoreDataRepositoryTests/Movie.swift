// Movie.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import CoreData
import CoreDataRepository

public struct Movie: Hashable {
    public let id: UUID
    public var title: String = ""
    public var releaseDate: Date
    public var boxOffice: Decimal = 0
    public var url: URL?
}

extension Movie: UnmanagedModel {
    public static var managedEntityDesc: NSEntityDescription {
        RepoMovie.entity()
    }

    public func asManaged(in context: NSManagedObjectContext) -> NSManagedObject {
        asRepoMovie(in: context)
    }
    
    public var managedRepoUrl: URL? {
        get {
            url
        }
        set(newValue) {
            url = newValue
        }
    }

    public func asRepoMovie(in context: NSManagedObjectContext) -> RepoMovie {
        let object = RepoMovie(context: context)
        object.id = id
        object.title = title
        object.releaseDate = releaseDate
        object.boxOffice = boxOffice as NSDecimalNumber
        return object
    }

    public func update(managed: NSManagedObject) throws {
        guard let repoMovie = managed as? RepoMovie else {
            throw CoreDataRepositoryError.fetchedObjectFailedToCastToExpectedType
        }
        repoMovie.update(from: self)
    }

    public func create(managed: NSManagedObject) throws {
        guard let repoMovie = managed as? RepoMovie else {
            throw CoreDataRepositoryError.fetchedObjectFailedToCastToExpectedType
        }
        repoMovie.create(from: self)
    }

    public static func tryMap(from object: NSManagedObject) throws -> Self {
        guard let repoMovie = object as? RepoMovie else {
            throw CoreDataRepositoryError.fetchedObjectFailedToCastToExpectedType
        }
        return repoMovie.asUnmanaged
    }

    public static func tryMapMany(from objects: [NSManagedObject]) throws -> [Self] {
        try objects.map(Self.tryMap(from:))
    }
}

@objc(RepoMovie)
public final class RepoMovie: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var releaseDate: Date?
    @NSManaged var boxOffice: NSDecimalNumber?
}

extension RepoMovie {
    public func create(from unmanaged: Movie) {
        update(from: unmanaged)
    }

    public typealias Unmanaged = Movie
    public var asUnmanaged: Movie {
        Movie(
            id: id ?? UUID(),
            title: title ?? "",
            releaseDate: releaseDate ?? Date(),
            boxOffice: (boxOffice ?? 0) as Decimal,
            url: objectID.uriRepresentation()
        )
    }

    public func update(from unmanaged: Movie) {
        id = unmanaged.id
        title = unmanaged.title
        releaseDate = unmanaged.releaseDate
        boxOffice = NSDecimalNumber(decimal: unmanaged.boxOffice)
    }

    static func fetchRequest() -> NSFetchRequest<RepoMovie> {
        let request = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        return request
    }
}
