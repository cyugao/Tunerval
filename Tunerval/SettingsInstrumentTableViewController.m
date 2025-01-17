//
//  SettingsInstrumentTableViewController.m
//  Tunerval
//
//  Created by Sam Bender on 7/9/16.
//  Copyright © 2016 Sam Bender. All rights reserved.
//

@import StoreKit;
#import <SBMusicUtilities/SBNote.h>
#import "SettingsInstrumentTableViewController.h"
#import "InstrumentTableViewCell.h"
#import "KeychainUserPass.h"
#import "SBEventTracker.h"

@interface SettingsInstrumentTableViewController () <SKProductsRequestDelegate, SKPaymentTransactionObserver, InstrumentTableViewCellDelegate>

@property (nonatomic, strong) NSArray *instrumentNames;
@property (nonatomic, strong) NSArray *instrumentValues;
@property (nonatomic, strong) NSArray *instrumentIAPIDs;
@property (nonatomic, strong) NSMutableArray *selectedInstruments;
@property (nonatomic, strong) NSMutableDictionary<NSString*, SKProduct*> *productCatalog;
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, strong) NSMutableArray<SKProductsRequest *> *productRequests;

@end

@implementation SettingsInstrumentTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [SBEventTracker trackScreenViewForScreenName:@"SettingsInstruments"];
    
    [self.navigationItem setTitle:@"Instruments"];
    [self.tableView setDelegate:self];
    [self removeTableCellButtonClickDelay];
    [self addRestorePurchasesBarButtonItem];
    
    [self loadDefaults];
    [self initializeConstants];
}

- (void)dealloc {
    if ([SKPaymentQueue canMakePayments]) {
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    }
    
    for (SKProductsRequest *productRequest in self.productRequests) {
        if (productRequest) {
            productRequest.delegate = nil;
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if ([SKPaymentQueue canMakePayments]) {
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    if ([SKPaymentQueue canMakePayments]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
}

- (void)loadDefaults
{
    self.defaults = [NSUserDefaults standardUserDefaults];
    self.selectedInstruments = [[self.defaults objectForKey:@"instruments"] mutableCopy];
    self.productRequests = [NSMutableArray<SKProductsRequest *> new];
}

- (void)initializeConstants
{
    self.instrumentNames = @[
                             @"Sine Wave",
                             @"Piano"
                             ];
    self.instrumentValues = @[
                              @(InstrumentTypeSineWave),
                              @(InstrumentTypePiano)
                              ];
    self.instrumentIAPIDs = @[
                              @"",
                              @"com.sambender.InstrumentTypePiano"
                              ];
}

- (void)removeTableCellButtonClickDelay
{
    self.tableView.delaysContentTouches = NO;
    for (UIView *currentView in self.tableView.subviews) {
        if ([currentView isKindOfClass:[UIScrollView class]]) {
            ((UIScrollView *)currentView).delaysContentTouches = NO;
            break;
        }
    }
}

- (void)addRestorePurchasesBarButtonItem
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"Restore" style:UIBarButtonItemStylePlain target:self action:@selector(restorePurchases)];
    [self.navigationItem setRightBarButtonItem:bbi];
}

#pragma mark - Tableview delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.instrumentNames.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    InstrumentTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InstrumentTableViewCell"];
    cell.tag = indexPath.row;
    cell.delegate = self;
    
    if (indexPath.row == 0 || [self isInstrumentAtIndexPurchased:indexPath.row])
    {
        [cell hideBuyButton];
    }
    
    NSNumber *instrument = self.instrumentValues[indexPath.row];
    [cell setCheckMarkHidden:![self.selectedInstruments containsObject:instrument]];
    [cell.instrumentNameLabel setText:self.instrumentNames[indexPath.row]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    InstrumentTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (cell.isSelected && self.selectedInstruments.count == 1) {
        return;
    }
    
    if (![self isInstrumentAtIndexPurchased:indexPath.row])
    {
        [self initiatePurchaseForInstrumentAtIndex:indexPath.row];
        return;
    }
    
    [cell toggleCheckMark];
    InstrumentType instrument = [self.instrumentValues[indexPath.row] integerValue];
    if (cell.isSelected) {
        [self.selectedInstruments addObject:@(instrument)];
    } else {
        [self.selectedInstruments removeObject:@(instrument)];
    }
    
    [self.defaults setObject:self.selectedInstruments forKey:@"instruments"];
}

#pragma mark - Instrument tableviewcell delegate

- (void)buyButtonPressedForCellAtIndex:(NSInteger)index
{
    [self initiatePurchaseForInstrumentAtIndex:index];
}

#pragma mark - In-app purchase helper

- (BOOL)isInstrumentAtIndexPurchased:(NSInteger)index
{
    
    if (index == 0) {
        return YES;
    }
    
    NSString *key = [NSString stringWithFormat:@"%@Purchased", self.instrumentIAPIDs[index]];
    BOOL purchased = [[self.defaults objectForKey:key] boolValue];
 
    return YES;
//    return purchased;
}

- (void)initiatePurchaseForInstrumentAtIndex:(NSInteger)instrumentIndex
{
    if (![SKPaymentQueue canMakePayments])
    {
        [self tellUserInAppPurchasesAreDisabled];
        return;
    }
    
    InstrumentTableViewCell *cell = [self.tableView
                                     cellForRowAtIndexPath:[NSIndexPath
                                                            indexPathForRow:instrumentIndex
                                                            inSection:0]];
    [cell hideBuyButtonAnimated];
    [cell startSpinner];
    
    SKProductsRequest *productRequest = [[SKProductsRequest alloc]
                                        initWithProductIdentifiers:
                                        [NSSet setWithObject:self.instrumentIAPIDs[instrumentIndex]]];
    
    productRequest.delegate = self;
    [productRequest start];
    
    [self.productRequests addObject:productRequest];
}

- (void)tellUserInAppPurchasesAreDisabled
{
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"In-App Purchases Disabled"
                                message:@"To purchase the instrument, enable In-App Purchases in Settings > General > Restrictions."
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *ok = [UIAlertAction
                         actionWithTitle:@"Ok"
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction * action)
                         {
                             [alert dismissViewControllerAnimated:YES completion:nil];
                         }];
    
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)askBeforeInitiatingPurchaseOfInstrumentAtIndex:(NSInteger)index
{
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"Purchase Required"
                                message:@"Would you like to purchase this instrument?"
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *yes = [UIAlertAction
                         actionWithTitle:@"Yes"
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction * action)
                         {
                             [self initiatePurchaseForInstrumentAtIndex:index];
                             [alert dismissViewControllerAnimated:YES completion:nil];
                         }];
    
    UIAlertAction *no = [UIAlertAction
                         actionWithTitle:@"No"
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction *action)
                         {
                             [alert dismissViewControllerAnimated:YES completion:nil];
                         }];
    
    [alert addAction:no];
    [alert addAction:yes];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Storekit delegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if (response.products.count < 1) {
        [SBEventTracker trackEvent:@"Error-NoProductsReturned" attributeName:@"InvalidIDs" attributeMsg:[response.invalidProductIdentifiers componentsJoinedByString:@","]];
        [self displayErrorDialogWithMessage:@"Error retrieving valid product identifiers from the store"];
        
        return;
    }
    
    // Purchase
    for (SKProduct *product in response.products) {
        [self addProductToCatalog:product];
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    [self displayDialogWithError:error];
}

#pragma mark - SKPaymentTransactionObserver delegate

- (void)paymentQueue:(SKPaymentQueue*)queue updatedTransactions:(NSArray*)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self handleTransactionStatePurchased:transaction];
                break;
                
            case SKPaymentTransactionStateFailed:
                [self handleTransactionStateFailed:transaction];
                break;
                
            case SKPaymentTransactionStateRestored:
                [self handleTransactionStateRestored:transaction];
                break;
                
            default:
                break;
        }
    }
}

- (void)handleTransactionStatePurchased:(SKPaymentTransaction*)transaction
{
    [SBEventTracker trackInstrumentPurchaseWithTransaction:transaction productCatalog:self.productCatalog];
    [self deliverPurchaseForTransaction:transaction];
}

- (void)handleTransactionStateRestored:(SKPaymentTransaction*)transaction
{
    [self deliverPurchaseForTransaction:transaction];
}

- (void)deliverPurchaseForTransaction:(SKPaymentTransaction*)transaction
{
    if (transaction.downloads)
    {
        [[SKPaymentQueue defaultQueue]
         startDownloads:transaction.downloads];
    }
    else
    {
        // Unlock feature or content here before finishing
        // transaction
        [[SKPaymentQueue defaultQueue]
         finishTransaction:transaction];
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    }
    
    // mark instrument as purchased
    NSString *key = [NSString stringWithFormat:@"%@Purchased", transaction.payment.productIdentifier];
    [self.defaults setObject:@(YES) forKey:key];
    
    // hide buy button and start downloading
    NSInteger index = [self.instrumentIAPIDs indexOfObject:transaction.payment.productIdentifier];
    InstrumentTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    [cell stopSpinner];
    [cell setDownloadProgress:0.0];
    
    // hide "new" on Instruments in settings
    [self.defaults setObject:@(YES) forKey:@"hide-new-label-in-settings-for-instruments"];
}

- (void)handleTransactionStateFailed:(SKPaymentTransaction*)transaction
{
    [[SKPaymentQueue defaultQueue]
     finishTransaction:transaction];
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [self displayDialogWithError:transaction.error];
}

- (void)paymentQueue:(SKPaymentQueue*)queue updatedDownloads:(NSArray*)downloads
{
    for (SKDownload *download in downloads)
    {
        switch (download.downloadState) {
            case SKDownloadStateActive:
                [self handleDownloadStateActive:download];
                break;
                
            case SKDownloadStateFinished:
                [self handleFinishedDownload:download];
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - SKPaymentTransactionObserverDelegate helper

- (void)handleDownloadStateActive:(SKDownload*)download
{
    InstrumentTableViewCell *cell = [self cellForIAPID:download.contentIdentifier];
    [cell setDownloadProgress:download.progress];
    NSLog(@"Download progress = %f",
          download.progress);
//    NSLog(@"Download time = %f",
//          download.timeRemaining);
}

- (void)handleFinishedDownload:(SKDownload*)download
{
    if ([self moveDownloadedFilesFrom:download]) {
        [self addInstrumentToSelectedInstrumetForInstrumentWithIAPID:download.contentIdentifier];
        
        InstrumentTableViewCell *cell = [self cellForIAPID:download.contentIdentifier];
        [cell setDownloadProgress:1.0];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

/**
 * Returns YES on success, NO otherwise
 */
- (BOOL)moveDownloadedFilesFrom:(SKDownload*)download
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:download.contentURL.path]) {
        return NO;
    }
    
    // convert url to string, suitable for NSFileManager
    NSString *path = [download.contentURL path];
    
    // files are in Contents directory
    path = [path stringByAppendingPathComponent:@"Contents"];
    
    NSError *error = nil;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:path error:&error];
    NSString *dir = [self applicationDocumentsDirectory].path; // not written yet
    
    for (NSString *file in files) {
        NSString *fullPathSrc = [path stringByAppendingPathComponent:file];
        NSString *fullPathDst = [dir stringByAppendingPathComponent:file];
        
        // not allowed to overwrite files - remove destination file
        [fileManager removeItemAtPath:fullPathDst error:NULL];
        
        if ([fileManager moveItemAtPath:fullPathSrc toPath:fullPathDst error:&error] == NO) {
            NSLog(@"Error: unable to move item: %@", error);
        }
    }
    
    [fileManager removeItemAtPath:download.contentURL.path error:nil];
    return YES;
}

#pragma mark - Actions

- (void) restorePurchases
{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - Helper 

- (NSURL*)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)addProductToCatalog:(SKProduct*)product
{
    [self.productCatalog setObject:product forKey:product.productIdentifier];
}

- (void)addInstrumentToSelectedInstrumetForInstrumentWithIAPID:(NSString*)IAPID
{
    NSUInteger IAPIDIndex = [self.instrumentIAPIDs indexOfObject:IAPID];
    if (IAPIDIndex == NSNotFound) return;
    
    if (![self.selectedInstruments containsObject:self.instrumentValues[IAPIDIndex]]) {
        [self.selectedInstruments addObject:self.instrumentValues[IAPIDIndex]];
        [self.defaults setObject:self.selectedInstruments forKey:@"instruments"];
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:IAPIDIndex inSection:0];
        InstrumentTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [cell showCheckMarkAnimated];
    }
}

- (InstrumentTableViewCell*)cellForIAPID:(NSString*)IAPID
{
    NSUInteger IAPIDIndex = [self.instrumentIAPIDs indexOfObject:IAPID];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:IAPIDIndex inSection:0];
    InstrumentTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    return cell;
}

#pragma mark - Properties

- (NSMutableDictionary*)productCatalog
{
    if (_productCatalog == nil) {
        _productCatalog = [NSMutableDictionary new];
    }
    
    return _productCatalog;
}

#pragma mark - Error handling

- (void)displayDialogWithError:(NSError*)error
{
    [SBEventTracker trackError:error];
    [self displayErrorDialogWithMessage:[error localizedDescription]];
}

- (void)displayErrorDialogWithMessage:(NSString*)message
{
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"Error"
                                message:message
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *yes = [UIAlertAction
                          actionWithTitle:@"Ok"
                          style:UIAlertActionStyleDefault
                          handler:^(UIAlertAction * action)
                          {
                              [alert dismissViewControllerAnimated:YES completion:nil];
                              [self dismissViewControllerAnimated:YES completion:nil];
                          }];
    
    [alert addAction:yes];
    [self presentViewController:alert animated:YES completion:nil];
}


@end
