//
//  AppDelegate.m
//  ZKManualMigration
//
//  Created by Zeeshan Khan on 03/11/14.
//  Copyright (c) 2014 Zeeshan. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    if ([self isMigrationNeeded]) {
        NSError *err = nil;
        [self migrate:&err];

        [self addFriend:@{@"name": @"Suraj", @"gender":@"Male", @"home":@"Calcutta"}];
        [self addFriend:@{@"name": @"Zeeshan", @"gender":@"Male", @"home":@"Bilaspur"}];
        [self addFriend:@{@"name": @"Ritesh", @"gender":@"Male", @"home":@"Nagpur"}];
    }
    else {
        [self addFriend:@{@"name": @"Rachel", @"gender":@"Female"}];
        [self addFriend:@{@"name": @"Ross", @"gender":@"Male"}];
        [self addFriend:@{@"name": @"Monica", @"gender":@"Female"}];
        [self addFriend:@{@"name": @"Chandler", @"gender":@"Male"}];
        [self addFriend:@{@"name": @"Pheabe", @"gender":@"Female"}];
        [self addFriend:@{@"name": @"Joe", @"gender":@"Male"}];
    }
    
    [self getFriends];
    
    return YES;
}

- (void)addFriend:(NSDictionary*)dicFriend {

    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friends" inManagedObjectContext:self.managedObjectContext];
    NSManagedObject *friendRow = [[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.managedObjectContext];
    if (friendRow) {
        [friendRow setValue:[dicFriend objectForKey:@"name"] forKey:@"name"];
        [friendRow setValue:[dicFriend objectForKey:@"gender"] forKey:@"gender"];
        NSString *home = [dicFriend objectForKey:@"home"];
        if (home)   [friendRow setValue:home forKey:@"home"];
    }
    
    [self saveContext];
}

- (NSArray*)getFriends {

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friends" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setResultType:NSDictionaryResultType];
    
    NSError *error = nil;
    NSArray *arrResult = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if (error != nil)
        NSLog(@"GET Error: %@", error.debugDescription);
    else
        NSLog(@"Friends %@", arrResult);
    
    return arrResult;
}

- (void)saveContext {
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            NSLog(@"Save Failed Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil)
        return _managedObjectContext;
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil)
        return _managedObjectModel;

    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"ZKManualMigration" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	
    if (_persistentStoreCoordinator != nil)
        return _persistentStoreCoordinator;
	
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
	NSError *error = nil;
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:[self sourceStoreURL]
                                                         options:@{NSInferMappingModelAutomaticallyOption: @YES}
                                                           error:&error]) {
        NSLog(@"Persistent Store Error: %@", error);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


- (NSURL *)sourceStoreURL {
    NSURL *dir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *oldFile = [dir URLByAppendingPathComponent:@"ZKManualMigration.sqlite"];
    return oldFile;
}


- (BOOL)isMigrationNeeded {
    
    NSError *error = nil;
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                              URL:[self sourceStoreURL]
                                                                                            error:&error];
    BOOL isMigrationNeeded = NO;
    if (sourceMetadata != nil) {
        
        NSManagedObjectModel *destinationModel = [self managedObjectModel];
        // Migration is needed if destinationModel is NOT compatible
        isMigrationNeeded = ![destinationModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata];
    }
    
    NSLog(@"isMigrationNeeded: %@", (isMigrationNeeded == YES) ? @"YES" : @"NO");
    return isMigrationNeeded;
}


- (BOOL)migrate:(NSError *__autoreleasing *)error {
    
    NSURL *sourceUrl = [self sourceStoreURL];
    
    // - Get metadata for source store from its URL with given type.
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:sourceUrl error:error];
    if (sourceMetadata == NO) {
        NSLog(@"FAILED to create source meta data");
        return NO;
    }
    
    
    // - Create model from source store meta deta,
    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle]] forStoreMetadata:sourceMetadata];
    if (sourceModel == nil) {
        NSLog(@"FAILED to create source model, something wrong with source xcdatamodel.");
        return NO;
    }
    
    
    NSManagedObjectModel *destinationModel = [self managedObjectModel];
    NSMappingModel *mappingModel = [NSMappingModel mappingModelFromBundles:@[[NSBundle mainBundle]]
                                       forSourceModel:sourceModel
                                     destinationModel:destinationModel];
    
    
    // - Create the destination store url
    NSString *fileName = @"ZKManualMigration_V2.sqlite";
    NSURL *destinationStoreURL =  [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:fileName];
    
    
    // - Migrate from source to latest matched destination model,
    NSMigrationManager *manager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel destinationModel:destinationModel];
    BOOL didMigrate = [manager migrateStoreFromURL:sourceUrl
                                              type:NSSQLiteStoreType
                                           options:nil
                                  withMappingModel:mappingModel
                                  toDestinationURL:destinationStoreURL
                                   destinationType:NSSQLiteStoreType
                                destinationOptions:nil
                                             error:error];
    if (!didMigrate) {
        return NO;
    }
    
    NSLog(@"Migrating from source: %@ ===To=== %@", sourceUrl.path, destinationStoreURL.path);
    
    // Delete old sqlite file
    NSError *err = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm removeItemAtURL:sourceUrl error:&err]) {
        NSLog(@"File delete failed.");
        return NO;
    }

    NSString *str1 = [NSString stringWithFormat:@"%@-shm",sourceUrl.path];
    [fm removeItemAtURL:[NSURL fileURLWithPath:str1] error:&err];
    str1 = [NSString stringWithFormat:@"%@-wal",sourceUrl.path];
    [fm removeItemAtURL:[NSURL fileURLWithPath:str1] error:&err];
    
    // Copy into new location
    if (![fm moveItemAtURL:destinationStoreURL toURL:sourceUrl error:&err]) {
        NSLog(@"File move failed.");
        return NO;
    }

    NSLog(@"Migration successful");
    
    return didMigrate;
}

@end
