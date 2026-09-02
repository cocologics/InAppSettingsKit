//
//  IASKHiddenKeysSelectionTests.m
//  InAppSettingsKit
//

@import XCTest;
@import UIKit;
@import InAppSettingsKit;

/// Regression tests for the per-section selection array going stale.
///
/// `-setHiddenKeys:animated:` takes an incremental path when animated: it swaps the
/// datasource and then inserts/deletes sections directly, instead of reloading. That
/// path did not rebuild the selection array, which is indexed by section, so a radio
/// group in a newly revealed section indexed past the end of the stale array while the
/// table view built its cells inside `endUpdates`, raising
/// `*** -[__NSArrayM objectAtIndexedSubscript:]: index 1 beyond bounds [0 .. 0]`.
///
/// The fixture keeps one always-visible section so the stale array holds exactly one
/// entry, reproducing those bounds precisely.
@interface IASKHiddenKeysSelectionTests : XCTestCase
@end

@implementation IASKHiddenKeysSelectionTests

- (IASKAppSettingsViewController *)presentedController {
	IASKAppSettingsViewController *viewController = [IASKAppSettingsViewController new];
	viewController.bundle = SWIFTPM_MODULE_BUNDLE;
	viewController.file = @"RadioGroupHiding";

	UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
	window.rootViewController = viewController;
	[window makeKeyAndVisible];
	[viewController.tableView layoutIfNeeded];
	return viewController;
}

/// Builds every cell, which is what the table view does while animating updates.
- (void)buildEveryCell:(IASKAppSettingsViewController *)viewController {
	UITableView *tableView = viewController.tableView;
	NSInteger sections = [viewController numberOfSectionsInTableView:tableView];
	for (NSInteger section = 0; section < sections; section++) {
		NSInteger rows = [viewController tableView:tableView numberOfRowsInSection:section];
		for (NSInteger row = 0; row < rows; row++) {
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
			XCTAssertNoThrow([viewController tableView:tableView cellForRowAtIndexPath:indexPath],
							 @"building the cell at section %ld row %ld must not raise",
							 (long)section, (long)row);
		}
	}
}

/// Revealing a hidden radio-group section with an animated update must not raise.
/// This is the PROC-4277 crash: before the fix this raised NSRangeException.
- (void)testRevealingHiddenRadioGroupSectionAnimatedDoesNotRaise {
	IASKAppSettingsViewController *viewController = [self presentedController];

	// Non-animated, so this goes through the full-reload path that always rebuilt
	// the selections. Only the always-visible section remains.
	viewController.hiddenKeys = [NSSet setWithObject:@"radiogroup"];
	[viewController.tableView layoutIfNeeded];
	XCTAssertEqual([viewController numberOfSectionsInTableView:viewController.tableView], 1,
				   @"only the always-visible section should remain while the radio group is hidden");

	// Animated, so this goes through the incremental path and inserts section 1.
	XCTAssertNoThrow([viewController setHiddenKeys:[NSSet set] animated:YES]);
	XCTAssertNoThrow([viewController.tableView layoutIfNeeded]);
	XCTAssertEqual([viewController numberOfSectionsInTableView:viewController.tableView], 2,
				   @"the radio group section should be back");

	[self buildEveryCell:viewController];
}

/// The reverse direction must stay consistent too.
- (void)testHidingRadioGroupSectionAnimatedDoesNotRaise {
	IASKAppSettingsViewController *viewController = [self presentedController];

	XCTAssertNoThrow([viewController setHiddenKeys:[NSSet setWithObject:@"radiogroup"] animated:YES]);
	XCTAssertNoThrow([viewController.tableView layoutIfNeeded]);

	[self buildEveryCell:viewController];
}

@end
