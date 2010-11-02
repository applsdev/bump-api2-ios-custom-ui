//
//  BumpAPIUI.m
//  BumpAPI
//
//  Copyright (c) 2010, Bump Technologies, Inc.
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//      * Neither the name of Bump Technologies, Inc. nor the
//        names of its contributors may be used to endorse or promote products
//        derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "BumpAPIUI.h"
#import "BumpAPIPopup.h"
#import "BumpAPIPromptPage.h"
#import "BumpAPIConfirmPage.h"
#import "BumpAPIWaitPage.h"
#import <QuartzCore/QuartzCore.h>

#define UI_W 260
#define UI_H 260
#define UI_Y_OFFSET 80


@interface BumpAPIUI ()
@property (nonatomic, retain) UIView *thePopup;
@property (nonatomic, retain) UIView *uiContainer;
@end

@implementation BumpAPIUI
@synthesize parentView = _parentView;
@synthesize uiContainer = _uiContainer;
@synthesize thePopup = _thePopup;
@synthesize bumpAPIObject = _bumpAPIObject;

#pragma mark Utility
-(void)closeUI {
	// set up an animation for the popup fade transition
	CATransition *animation = [CATransition animation];
	[animation setDuration:0.2];
	[animation setType:kCATransitionFade];
	[animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
	[[_uiContainer.superview layer] addAnimation:animation forKey:@"fade_pages"];

	[_uiContainer removeFromSuperview];
	self.thePopup = nil;
	self.uiContainer = nil;
}

#pragma mark -
#pragma mark Default BumpMatchUI delegate

-(void)bumpRequestSessionCalled{
	//Setup our popup UI
	//Just incase we're showing a new popup before the closeUI selector was called with delay
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(closeUI) object:nil];
	UIViewAutoresizing flexible = (UIViewAutoresizingFlexibleWidth |
								   UIViewAutoresizingFlexibleHeight);

	UIViewAutoresizing pinnedToTop = (UIViewAutoresizingFlexibleLeftMargin |
									  UIViewAutoresizingFlexibleRightMargin |
									  UIViewAutoresizingFlexibleBottomMargin);

	self.uiContainer = [[[UIView alloc] initWithFrame:[_parentView bounds]] autorelease];
	UIView *colorOverlay = [[UIView alloc] initWithFrame:[_parentView bounds]];
	[colorOverlay setBackgroundColor:[UIColor whiteColor]];
	[colorOverlay setAlpha:0.4];
	[_uiContainer addSubview:colorOverlay];
	[_uiContainer setAutoresizingMask:flexible];
	[colorOverlay setAutoresizingMask:flexible];
	[colorOverlay release];
	
	CGRect popupRect = CGRectMake(_uiContainer.bounds.size.width / 2.0 - UI_W / 2.0, 
								  UI_Y_OFFSET, 
								  UI_W,
								  UI_H);
	
	popupRect = CGRectIntegral(popupRect);
	
	self.thePopup = [[[BumpAPIPopup alloc] initWithFrame:popupRect] autorelease];
	[_thePopup setAutoresizingMask:pinnedToTop];
	[_thePopup setDelegate:self];
	[_uiContainer addSubview:_thePopup];
	[_parentView addSubview:_uiContainer];
	BumpAPIPromptPage *promptPage = [[BumpAPIPromptPage alloc] initWithFrame:CGRectZero];
	[promptPage setPromptText:NSLocalizedStringFromTable(@"Warming up", @"BumpApiLocalizable", @"Notifying the user the phone is establishing a connection.")];
	[_thePopup changePage:promptPage];
	[promptPage release];
	[_thePopup show];	
	//Add a bump button in the simulator for testing.
#ifdef __i386__
	UIButton *bumpButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[bumpButton setFrame:CGRectMake(CGRectGetMaxX([_uiContainer bounds])-65, 10, 60, 45)];
	[bumpButton setTitle:@"Bump" forState:UIControlStateNormal];
	[bumpButton addTarget:_bumpAPIObject action:@selector(simulateBump) forControlEvents:UIControlEventTouchUpInside];
	[_uiContainer addSubview:bumpButton];
#endif
	//show the UI for bumping
}

- (void)bumpFailedToConnectToBumpNetwork {
    //close the bumping UI
	[self closeUI];
}

- (void)bumpConnectedToBumpNetwork {
	BumpAPIPromptPage *promptPage = [[BumpAPIPromptPage alloc] initWithFrame:CGRectZero];
	[promptPage setPromptText:NSLocalizedStringFromTable(@"Bump to connect", @"BumpApiLocalizable", @"Explains to users that the phone is ready and they should bump to connect with another phone.")];
	[promptPage setSubText:[_bumpAPIObject actionMessage]];
	[_thePopup changePage:promptPage];
	[promptPage release];
}

/**
 * Result of endSession call on BumpAPI. This is to handle the case when for some reason your code 
 * calls endSession while the UI is up. Should likely close the bumping UI.
 */
-(void)bumpEndSessionCalled{
    //close the bumping UI
	[self closeUI];
}

/**
 * Physical bump occurced. Update ui to tell user that a bump has occured
 */
-(void)bumpOccurred{
	BumpAPIWaitPage *newPage = [[BumpAPIWaitPage alloc] initWithFrame:CGRectZero];
	[newPage setPromptText:NSLocalizedStringFromTable(@"Connecting...", @"BumpApiLocalizable", @"Dialog shown when user has just bumped and information is sending to the other phone.")];
	[newPage startSpinner];
	[_thePopup changePage:newPage];
	[newPage release];
}

/**
 * Let's you know that a match could not be made via a bump. It's best to prompt users to try again.
 */
-(void)bumpMatchFailedReason:(BumpMatchFailedReason)reason{
	BumpAPIWaitPage *newPage = [[BumpAPIWaitPage alloc] initWithFrame:CGRectZero];
	NSMutableString *bodyText = [NSMutableString stringWithString:NSLocalizedStringFromTable(@"Please bump again", @"BumpApiLocalizable", @"Ask user to try to bump phones again.")];
	if (reason == NoMatch_ReasonNoConfirm) {
		[bodyText appendFormat:@"\n%@", NSLocalizedStringFromTable(@"Other user canceled the bump.", @"BumpApiLocalizable",
									 @"Explain that the other user decided to cancel the bump and the information was not transferred.")];
	} else if (reason == NoMatch_ReasonAlone) {
		[bodyText appendFormat:@"\n%@", NSLocalizedStringFromTable(@"You were the only one to bump.", @"BumpApiLocalizable",
																   @"The other phone did not register a bump. Explain why the user must bump again.")];
	} else {
		[bodyText appendFormat:@"\n%@", NSLocalizedStringFromTable(@"Sometimes two bumps are required.", @"BumpApiLocalizable",
																   @"There were too many possible candidates for the server to match.")];
	}

	[newPage setPromptText:bodyText];
	[newPage stopSpinner];
	[_thePopup changePage:newPage];
	[newPage release];
}

/**
 * The user should be presented with some data about who they matched, and whether they want to
 * accept this connection. (Pressing Yes/No should call confirmMatch:(BOOL) on the BumpAPI)
 */
-(void)bumpMatched:(Bumper*)bumper{
	BumpAPIConfirmPage *newPage = [[BumpAPIConfirmPage alloc] initWithFrame:CGRectZero];
	[newPage setPromptText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Connect with %@?", @"BumpApiLocalizable", @"Request to connect with another user. For example, this might say Connect with Andy?."), bumper.userName]];
	 [newPage.yesButton addTarget:self action:@selector(yesPressed) forControlEvents:UIControlEventTouchUpInside];
	 [newPage.noButton addTarget:self action:@selector(noPressed) forControlEvents:UIControlEventTouchUpInside];
	[_thePopup changePage:newPage];
	[newPage release];
}

/**
 * Once the intial connection to the bump network has been made, there is a chance the connection
 * to the Bump Network is severed. In this case the bump network might come back, so it's
 * best to put the user back in the warming up state. If this happens too often then you can 
 * provide extra messaging and/or explicitly call endSession on the BumpAPI.
 */
-(void)bumpNetworkLost {
	BumpAPIPromptPage *promptPage = [[BumpAPIPromptPage alloc] initWithFrame:CGRectZero];
	[promptPage setPromptText:NSLocalizedStringFromTable(@"Warming up", @"BumpApiLocalizable", @"Notifying the user the phone is establishing a connection.")];
	[_thePopup changePage:promptPage];
	[promptPage release];
}

/**
 * After both parties have pressed yes, And bumpSessionStartedWith:(Bumper) is about to be called
 * on the API Delegate.
 */
-(void)bumpSessionStarted{
	[self closeUI];
}

#pragma mark - 
#pragma mark BumpAPIPopupDelegate
-(void) popupCloseButtonPressed{
	[_bumpAPIObject cancelMatching];
	[self closeUI];
}
	 
#pragma mark -
#pragma mark Confirm page buttons
- (void)yesPressed{
	[_bumpAPIObject confirmMatch:YES];
	
	BumpAPIWaitPage *newPage = [[BumpAPIWaitPage alloc] initWithFrame:CGRectZero];
	[newPage setPromptText:NSLocalizedStringFromTable(@"Please wait", @"BumpApiLocalizable", @"This message asks the user to please wait while the Bump service is doing something.")];
	[newPage startSpinner];
	[_thePopup changePage:newPage];
	[newPage release];
}
- (void) noPressed{
	[_bumpAPIObject confirmMatch:NO];
	
	BumpAPIPromptPage *promptPage = [[BumpAPIPromptPage alloc] initWithFrame:CGRectZero];
	[promptPage setPromptText:NSLocalizedStringFromTable(@"Bump to connect", @"BumpApiLocalizable", @"Explains to users that the phone is ready and they should bump to connect with another phone.")];
	[promptPage setSubText:[_bumpAPIObject actionMessage]];
	[_thePopup changePage:promptPage];
	[promptPage release];
}

- (void) dealloc{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super dealloc];
}

@end
