import Foundation
import CoreData

/// Controller for managing Core Data persistence
final class PersistenceController {
    static let shared = PersistenceController()

    /// The persistent container for Core Data
    let container: NSPersistentContainer

    /// URL of the Core Data store
    var storeURL: URL? {
        container.persistentStoreDescriptions.first?.url
    }

    /// Main managed object context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for off-main-thread operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    private init() {
        // Create the Core Data model programmatically
        let model = Self.createModel()
        container = NSPersistentContainer(name: "DemoskopClipboard", managedObjectModel: model)

        // Configure store location
        let storeURL = Self.defaultStoreURL()
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [storeDescription]

        // Load the persistent store
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Failed to load Core Data store: \(error)")
                // In production, handle this more gracefully
                fatalError("Failed to load Core Data: \(error)")
            }
            print("Core Data store loaded: \(description.url?.path ?? "unknown")")
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Creates the Core Data model programmatically
    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Create ClipboardEntryMO entity
        let entity = NSEntityDescription()
        entity.name = "ClipboardEntryMO"
        entity.managedObjectClassName = "ClipboardEntryMO"

        // Define attributes
        var attributes: [NSAttributeDescription] = []

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        attributes.append(idAttr)

        let timestampAttr = NSAttributeDescription()
        timestampAttr.name = "timestamp"
        timestampAttr.attributeType = .dateAttributeType
        timestampAttr.isOptional = false
        attributes.append(timestampAttr)

        let plainTextAttr = NSAttributeDescription()
        plainTextAttr.name = "plainText"
        plainTextAttr.attributeType = .stringAttributeType
        plainTextAttr.isOptional = false
        attributes.append(plainTextAttr)

        let rtfDataAttr = NSAttributeDescription()
        rtfDataAttr.name = "rtfData"
        rtfDataAttr.attributeType = .binaryDataAttributeType
        rtfDataAttr.isOptional = true
        attributes.append(rtfDataAttr)

        let htmlStringAttr = NSAttributeDescription()
        htmlStringAttr.name = "htmlString"
        htmlStringAttr.attributeType = .stringAttributeType
        htmlStringAttr.isOptional = true
        attributes.append(htmlStringAttr)

        let hasMarkdownAttr = NSAttributeDescription()
        hasMarkdownAttr.name = "hasMarkdown"
        hasMarkdownAttr.attributeType = .booleanAttributeType
        hasMarkdownAttr.isOptional = false
        hasMarkdownAttr.defaultValue = false
        attributes.append(hasMarkdownAttr)

        let isFavoriteAttr = NSAttributeDescription()
        isFavoriteAttr.name = "isFavorite"
        isFavoriteAttr.attributeType = .booleanAttributeType
        isFavoriteAttr.isOptional = false
        isFavoriteAttr.defaultValue = false
        attributes.append(isFavoriteAttr)

        let tagsAttr = NSAttributeDescription()
        tagsAttr.name = "tags"
        tagsAttr.attributeType = .stringAttributeType
        tagsAttr.isOptional = true
        attributes.append(tagsAttr)

        entity.properties = attributes

        model.entities = [entity]

        return model
    }

    /// Returns the default store URL in Application Support
    private static func defaultStoreURL() -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupportURL.appendingPathComponent("se.demoskop.clipboard", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        return appFolder.appendingPathComponent("ClipboardHistory.sqlite")
    }

    /// Saves the view context if there are changes
    func save() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save Core Data context: \(error)")
        }
    }

    /// Saves a background context
    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save background context: \(error)")
        }
    }
}

// MARK: - Managed Object Class

@objc(ClipboardEntryMO)
public class ClipboardEntryMO: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var plainText: String?
    @NSManaged public var rtfData: Data?
    @NSManaged public var htmlString: String?
    @NSManaged public var hasMarkdown: Bool
    @NSManaged public var isFavorite: Bool
    @NSManaged public var tags: String?
}
