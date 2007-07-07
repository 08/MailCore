#import "CTCoreMessageTests.h"
#import "CTMIMETests.h"
#import "CTCoreAddress.h"

@implementation CTCoreMessageTests
- (void)setUp {
	myMsg = [[CTCoreMessage alloc] init];
	myRealMsg = [[CTCoreMessage alloc] initWithFileAtPath:[NSString stringWithFormat:@"%@%@",filePrefix,@"TestData/kiwi-dev/1167196014.6158_0.theronge.com:2,Sab"]];
}

- (void)tearDown {
	[myMsg release];
	[myRealMsg release];
}

- (void)testBasicSubject {
	[myMsg setSubject:@"Test value1!"];
	STAssertEqualObjects(@"Test value1!", [myMsg subject], @"Basic set and get of subject failed.");
}

- (void)testReallyLongSubject {
	NSString *reallyLongStr = @"faldskjfalkdjfal;skdfjl;ksdjfl;askjdflsadjkfsldfkjlsdfjkldskfjlsdkfjlskdfjslkdfjsdlkfjsdlfkjsdlfkjsdlfkjsdlkfjsdlfkjsdlfkjsldfjksldkfjsldkfjsdlfkjdslfjdsflkjdsflkjdsfldskjfsdlkfjsdlkfjdslkfjsdlkfjdslfkjfaldskjfalkdjfal;skdfjl;ksdjfl;askjdflsadjkfsldfkjlsdfjkldskfjlsdkfjlskdfjslkdfjsdlkfjsdlfkjsdlfkjsdlfkjsdlkfjsdlfkjsdlfkjsldfjksldkfjsldkfjsdlfkjdslfjdsflkjdsflkjdsfldskjfsdlkfjsdlkfjdslkfjsdlkfjdslfkjfaldskjfalkdjfal;skdfjl;ksdjfl;askjdflsadjkfsldfkjlsdfjkldskfjlsdkfjlskdfjslkdfjsdlkfjsdlfkjsdlfkjsdlfkjsdlkfjsdlfkjsdlfkjsldfjksldkfjsldkfjsdlfkjdslfjdsflkjdsflkjdsfldskjfsdlkfjsdlkfjdslkfjsdlkfjdslfkjaskjdflsadjkfsldfkjlsdfjkldskfjlsdkfjlskdfjslkdfjsdlkfjsdlfkjsdlfkjsdlfkjsdlkfjsdlfkjsdlfkjsldfjksldkfjsldkfjsdlfkjdslfjdsflkjdsflkjdsfldskjfsdlkfjsdlkfjdslkfjsdlkfjdslfkjaskjdflsadjkfsldfkjlsdfjkldskfjlsdkfjlskdfjslkdfjsdlkfjsdlfkjsdlfkjsdlfkjsdlkfjsdlfkjsdlfkjsldfjksldkfjsldkfjsdlfkjdslfjdsflkjdsflkjdsfldskjfsdlkfjsdlkfjdslkfjsdlkfjdslfkj";
	[myMsg setSubject:reallyLongStr];
	STAssertEqualObjects(reallyLongStr, [myMsg subject], @"Failed to set and get a really long subject.");
}

- (void)testEmptySubject {
	[myMsg setSubject:@""];
	STAssertEqualObjects(@"", [myMsg subject], @"Failed to set and get an empty subject.");
}

- (void)testEmptyBody {
	[myMsg setBody:@""];
	STAssertEqualObjects(@"", [myMsg body], @"Failed to set and get an empty body.");
}

- (void)testBasicBody {
	[myMsg setBody:@"Test"];
	STAssertEqualObjects(@"Test", [myMsg body], @"Failed to set and get a message body.");
}

- (void)testSubjectOnData {
	CTCoreMessage *msg = [[CTCoreMessage alloc] initWithFileAtPath:[NSString stringWithFormat:@"%@%@",filePrefix,@"TestData/kiwi-dev/1167196014.6158_0.theronge.com:2,Sab"]];
	[msg fetchBody];
	STAssertEqualObjects(@"[Kiwi-dev] Revision 16", [msg subject], @"");
	NSRange notFound = NSMakeRange(NSNotFound, 0);
	STAssertTrue(!NSEqualRanges([[msg body] rangeOfString:@"Kiwi-dev mailing list"],notFound), @"Body sanity check failed!");
	[msg release];
}

- (void)testRender {
	CTCoreMessage *msg = [[CTCoreMessage alloc] init];
	[msg setBody:@"test"];
	NSString *str = [msg render];
	/* Do a few sanity checks on the str */
	NSRange notFound = NSMakeRange(NSNotFound, 0);
	STAssertTrue(!NSEqualRanges([str rangeOfString:@"Date:"],notFound), @"Render sanity check failed!");
	STAssertTrue(!NSEqualRanges([str rangeOfString:@"Message-ID:"],notFound), @"Render sanity check failed!");	
	STAssertTrue(!NSEqualRanges([str rangeOfString:@"MIME-Version: 1.0"],notFound), @"Render sanity check failed!");	
	STAssertTrue(!NSEqualRanges([str rangeOfString:@"test"],notFound), @"Render sanity check failed!");
	STAssertTrue(!NSEqualRanges([str rangeOfString:@"Content-Transfer-Encoding:"],notFound), @"Render sanity check failed!");	
	STAssertTrue(NSEqualRanges([str rangeOfString:@"not there"],notFound), @"Render sanity check failed!");	
}

- (void)testRenderWithToField {
	CTCoreMessage *msg = [[CTCoreMessage alloc] init];
	[msg setBody:@"This is some kind of message."];
	[msg setTo:[NSArray arrayWithObjects:[CTCoreAddress addressWithName:@"Matt" email:@"test@test.com"],nil]];
	NSString *str = [msg render];
	/* Do a few sanity checks on the str */
	NSRange notFound = NSMakeRange(NSNotFound, 0);
	STAssertTrue(!NSEqualRanges([str rangeOfString:@"message"],notFound), @"Render sanity check failed!");
	STAssertTrue(!NSEqualRanges([str rangeOfString:@"To: Matt <test@test.com>"],notFound), @"Render sanity check failed!");	
}

- (void)testTo {
	NSSet *to = [myRealMsg to];
	STAssertTrue([to count] == 1, @"To should only contain 1 address!");
	CTCoreAddress *addr = [CTCoreAddress addressWithName:@"" email:@"kiwi-dev@lists.theronge.com"];
	STAssertEqualObjects(addr, [to anyObject], @"The only address object should have been kiwi-dev@lists.theronge.com");
}

- (void)testFrom {
	NSSet *from = [myRealMsg from];
	STAssertTrue([from count] == 1, @"To should only contain 1 address!");
	CTCoreAddress *addr = [CTCoreAddress addressWithName:@"" email:@"kiwi-dev@lists.theronge.com"];
	STAssertEqualObjects(addr, [from anyObject], @"The only address object should have been kiwi-dev@lists.theronge.com");
}

- (void)testEmptyBcc {
	STAssertTrue([myRealMsg bcc] != nil, @"Shouldn't have been nil");
	STAssertTrue([[myRealMsg bcc] count] == 0, @"There shouldn't be any bcc's");
}

- (void)testEmptyCc {
	STAssertTrue([myRealMsg cc] != nil, @"Shouldn't have been nil");
	STAssertTrue([[myRealMsg cc] count] == 0, @"There shouldn't be any cc's");
}

- (void)testSender {
	STAssertEqualObjects([myRealMsg sender], [CTCoreAddress addressWithName:@"" email:@"kiwi-dev-bounces@lists.theronge.com"], @"Sender returned is incorrect!");
}

- (void)testReplyTo {
	NSSet *replyTo = [myRealMsg replyTo];
	STAssertTrue([replyTo count] == 1, @"To should only contain 1 address!");
	CTCoreAddress *addr = [CTCoreAddress addressWithName:@"" email:@"kiwi-dev@lists.theronge.com"];
	STAssertEqualObjects(addr, [replyTo anyObject], @"The only address object should have been kiwi-dev@lists.theronge.com");
}

- (void)testSentDate {
	NSCalendarDate *sentDate = [myRealMsg sentDate];
	NSCalendarDate *actualDate = [[NSCalendarDate alloc] initWithString:@"2006-12-26 21:06:49 -0800"];
	STAssertEqualObjects(sentDate, actualDate, @"Date's should be equal!");
	[actualDate release];
}

- (void)testSettingFromTwice {
	CTCoreMessage *msg = [[CTCoreMessage alloc] init];
	[msg setFrom:[NSSet setWithObject:[CTCoreAddress addressWithName:@"Matt P" email:@"mattp@p.org"]]];
	[msg setFrom:[NSSet setWithObject:[CTCoreAddress addressWithName:@"Matt R" email:@"mattr@r.org"]]];
	[msg release];
}
@end
