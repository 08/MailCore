#import "CTCoreMessage.h"
#import "CTCoreFolder.h"
#import "CTMIMEParser.h"
#import "MailCoreTypes.h"
#import "CTCoreAddress.h"
#import "CTMIMEFactory.h"
#import "CTMIME_MessagePart.h"
#import "CTMIME_TextPart.h"
#import "CTMIME_MultiPart.h"

@interface CTCoreMessage (Private)
- (CTCoreAddress *)_addressFromMailbox:(struct mailimf_mailbox *)mailbox;
- (NSSet *)_addressListFromMailboxList:(struct mailimf_mailbox_list *)mailboxList;
- (struct mailimf_mailbox_list *)_mailboxListFromAddressList:(NSSet *)addresses;
- (NSSet *)_addressListFromIMFAddressList:(struct mailimf_address_list *)imfList;
- (struct mailimf_address_list *)_IMFAddressListFromAddresssList:(NSSet *)addresses;
- (void)_buildUpBodyText:(CTMIME *)mime result:(NSMutableString *)result;
@end

@implementation CTCoreMessage
- (id)init {
	[super init];
	if (self) {
		struct mailimf_fields *fields = mailimf_fields_new_empty();
		myFields = mailimf_single_fields_new(fields);
		mailimf_fields_free(fields);
	}
	return self;
}


- (id)initWithMessageStruct:(struct mailmessage *)message {
	self = [super init];
	if (self) {
		assert(message != NULL);
		myMessage = message;
		myFields = mailimf_single_fields_new(message->msg_fields);
		mailimf_single_fields_init(myFields, message->msg_fields);
	}
	return self;
}

- (id)initWithFileAtPath:(NSString *)path {
	NSString *msgData = [NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:NULL];
	struct mailmessage *msg = data_message_init((char *)[msgData cStringUsingEncoding:NSASCIIStringEncoding], [msgData lengthOfBytesUsingEncoding:NSASCIIStringEncoding]);
	int err;
	struct mailmime *dummyMime;
	/* mailmessage_get_bodystructure will fill the mailmessage struct for us */
	err = mailmessage_get_bodystructure(msg, &dummyMime);
	assert(err == 0);
	/* mailmessage_fetch_envelope does not fill the struct, so that's why we don't have a dummy variable */
	err = mailmessage_fetch_envelope(msg, &(msg->msg_fields));
	assert(err == 0);
	return [self initWithMessageStruct:msg];
}


- (void)dealloc {
	//TODO mailmessage_free?
	if (myMessage != NULL)
		mailmessage_free(myMessage);
	if (myFields != NULL)
		mailimf_single_fields_free(myFields);
	[myParsedMIME release];
	[super dealloc];
}



- (void)fetchBody {
	int err;
	struct mailmime *dummyMime;
	//Retrieve message mime and message field
	err = mailmessage_get_bodystructure(myMessage, &dummyMime);
	assert(err == 0);
	myParsedMIME = [[CTMIMEFactory createMIMEWithMIMEStruct:[self messageStruct]->msg_mime forMessage:[self messageStruct]] retain];
}


- (NSString *)body {
	NSMutableString *result = [NSMutableString string];
	[self _buildUpBodyText:myParsedMIME result:result];
	return result;
}

- (void)_buildUpBodyText:(CTMIME *)mime result:(NSMutableString *)result {
	if (mime == nil)
		return;
	
	if ([mime isKindOfClass:[CTMIME_MessagePart class]]) {
		[self _buildUpBodyText:[mime content] result:result];
	}
	else if ([mime isKindOfClass:[CTMIME_TextPart class]]) {
		[result appendString:[mime content]];
	}
	else if ([mime isKindOfClass:[CTMIME_MultiPart class]]) {
		//TODO need to take into account the different kinds of multipart
		NSEnumerator *enumer = [[mime content] objectEnumerator];
		CTMIME *subpart;
		while ((subpart = [enumer nextObject])) {
			[self _buildUpBodyText:subpart result:result];
		}
	}
}


- (void)setBody:(NSString *)body {
	CTMIME *oldMIME = myParsedMIME;
	CTMIME_TextPart *text = [CTMIME_TextPart mimeTextPartWithString:body];
	CTMIME_MessagePart *messagePart = [CTMIME_MessagePart mimeMessagePartWithContent:text];
	myParsedMIME = [messagePart retain];
	[oldMIME release];
}


- (NSString *)subject {
	if (myFields->fld_subject == NULL)
		return @"";
	NSString *decodedSubject = [CTMIMEParser decodeMIMEPhrase:myFields->fld_subject->sbj_value];
	if (decodedSubject == nil)
		return @"";
	return decodedSubject;
}


- (void)setSubject:(NSString *)subject {
	struct mailimf_subject *subjectStruct;
	
	subjectStruct = mailimf_subject_new(strdup([subject cStringUsingEncoding:NSASCIIStringEncoding]));
	if (myFields->fld_subject != NULL)
		mailimf_subject_free(myFields->fld_subject);
	myFields->fld_subject = subjectStruct;
}


- (NSCalendarDate *)sentDate {
  	if ( myFields->fld_orig_date == NULL)
    	return [NSDate distantPast];
  	else {
    	return [NSCalendarDate dateWithYear:myFields->fld_orig_date->dt_date_time->dt_year 
                                      month:myFields->fld_orig_date->dt_date_time->dt_month
                                        day:myFields->fld_orig_date->dt_date_time->dt_day
                                       hour:myFields->fld_orig_date->dt_date_time->dt_hour
                                     minute:myFields->fld_orig_date->dt_date_time->dt_min
                                    second:myFields->fld_orig_date->dt_date_time->dt_sec
                                   timeZone:[NSTimeZone systemTimeZone]];
  	}
}


- (BOOL)isNew {
	struct mail_flags *flags = myMessage->msg_flags;
	if (flags != NULL) {
		if ( (flags->fl_flags & MAIL_FLAG_SEEN == 0) && 
			(flags->fl_flags & MAIL_FLAG_NEW == 0))
			return YES;
	}
	return NO;
}


- (NSString *)uid {
	return [NSString stringWithCString:myMessage->msg_uid encoding:NSASCIIStringEncoding];
}


- (NSSet *)from {
	if (myFields->fld_from == NULL)
		return [NSSet set]; //Return just an empty set

	return [self _addressListFromMailboxList:myFields->fld_from->frm_mb_list];
}


- (void)setFrom:(NSSet *)addresses {
	struct mailimf_mailbox_list *imf = [self _mailboxListFromAddressList:addresses];
	if (myFields->fld_from != NULL)
		mailimf_from_free(myFields->fld_from);
	myFields->fld_from = mailimf_from_new(imf);	
}


- (CTCoreAddress *)sender {
	if (myFields->fld_sender == NULL)
		return [CTCoreAddress address];
		
	return [self _addressFromMailbox:myFields->fld_sender->snd_mb];
}


- (NSSet *)to {
	if (myFields->fld_to == NULL)
		return [NSSet set];
	else
		return [self _addressListFromIMFAddressList:myFields->fld_to->to_addr_list];
}


- (void)setTo:(NSSet *)addresses {
	struct mailimf_address_list *imf = [self _IMFAddressListFromAddresssList:addresses];
	
	if (myFields->fld_to != NULL) {
		mailimf_address_list_free(myFields->fld_to->to_addr_list);
		myFields->fld_to->to_addr_list = imf;
	}
	else
		myFields->fld_to = mailimf_to_new(imf);
}


- (NSSet *)cc {
	if (myFields->fld_cc == NULL)
		return [NSSet set];
	else
		return [self _addressListFromIMFAddressList:myFields->fld_cc->cc_addr_list];
}


- (void)setCc:(NSSet *)addresses {
	struct mailimf_address_list *imf = [self _IMFAddressListFromAddresssList:addresses];
	if (myFields->fld_cc != NULL) {
		mailimf_address_list_free(myFields->fld_cc->cc_addr_list);
		myFields->fld_cc->cc_addr_list = imf;
	}
	else
		myFields->fld_cc = mailimf_cc_new(imf);
}


- (NSSet *)bcc {
	if (myFields->fld_bcc == NULL)
		return [NSSet set];
	else
		return [self _addressListFromIMFAddressList:myFields->fld_bcc->bcc_addr_list];
}


- (void)setBcc:(NSSet *)addresses {
	struct mailimf_address_list *imf = [self _IMFAddressListFromAddresssList:addresses];
	if (myFields->fld_bcc != NULL) {
		mailimf_address_list_free(myFields->fld_bcc->bcc_addr_list);
		myFields->fld_bcc->bcc_addr_list = imf;
	}
	else
		myFields->fld_bcc = mailimf_bcc_new(imf);
}


- (NSSet *)replyTo {
	if (myFields->fld_reply_to == NULL)
		return [NSSet set];
	else
		return [self _addressListFromIMFAddressList:myFields->fld_reply_to->rt_addr_list];
}


- (void)setReplyTo:(NSSet *)addresses {
	struct mailimf_address_list *imf = [self _IMFAddressListFromAddresssList:addresses];
	if (myFields->fld_reply_to != NULL) {
		mailimf_address_list_free(myFields->fld_reply_to->rt_addr_list);
		myFields->fld_reply_to->rt_addr_list = imf;
	}
	else
		myFields->fld_reply_to = mailimf_reply_to_new(imf);
}


- (NSString *)render {
	if ([myParsedMIME isMemberOfClass:[myParsedMIME class]]) {
		/* It's a message part, so let's set it's fields */
		struct mailimf_fields *fields;
		struct mailimf_mailbox *sender = (myFields->fld_sender != NULL) ? (myFields->fld_sender->snd_mb) : NULL;
		struct mailimf_mailbox_list *from = (myFields->fld_from != NULL) ? (myFields->fld_from->frm_mb_list) : NULL;
		struct mailimf_address_list *replyTo = (myFields->fld_reply_to != NULL) ? (myFields->fld_reply_to->rt_addr_list) : NULL;
		struct mailimf_address_list *to = (myFields->fld_to != NULL) ? (myFields->fld_to->to_addr_list) : NULL;
		struct mailimf_address_list *cc = (myFields->fld_cc != NULL) ? (myFields->fld_cc->cc_addr_list) : NULL;
		struct mailimf_address_list *bcc = (myFields->fld_bcc != NULL) ? (myFields->fld_bcc->bcc_addr_list) : NULL;
		clist *inReplyTo = (myFields->fld_in_reply_to != NULL) ? (myFields->fld_in_reply_to->mid_list) : NULL;
		clist *references = (myFields->fld_references != NULL) ? (myFields->fld_references->mid_list) : NULL;
		char *subject = (myFields->fld_subject != NULL) ? (myFields->fld_subject->sbj_value) : NULL;
		
		fields = mailimf_fields_new_with_data(from, sender, replyTo, to, cc, bcc, inReplyTo, references, subject);
		[(CTMIME_MessagePart *)myParsedMIME setIMFFields:fields];
	}
	return [myParsedMIME render];
}


- (struct mailmessage *)messageStruct {
	return myMessage;
}

/*********************************** myprivates ***********************************/
- (CTCoreAddress *)_addressFromMailbox:(struct mailimf_mailbox *)mailbox; {
	CTCoreAddress *address = [CTCoreAddress address];
	if (mailbox == NULL)
		return address;
	if (mailbox->mb_display_name != NULL)
		[address setName:[NSString stringWithCString:mailbox->mb_display_name encoding:NSASCIIStringEncoding]];
	if (mailbox->mb_addr_spec != NULL)
		[address setEmail:[NSString stringWithCString:mailbox->mb_addr_spec encoding:NSASCIIStringEncoding]];
	return address;
}


- (NSSet *)_addressListFromMailboxList:(struct mailimf_mailbox_list *)mailboxList; {
	clist *list;
	clistiter * iter;
	struct mailimf_mailbox *address;
	NSMutableSet *addressSet = [NSMutableSet set];
	
	if (mailboxList == NULL)
		return addressSet;
		
	list = mailboxList->mb_list;
	for(iter = clist_begin(list); iter != NULL; iter = clist_next(iter)) {
    	address = clist_content(iter);
		[addressSet addObject:[self _addressFromMailbox:address]];
  	}
	return addressSet;
}


- (struct mailimf_mailbox_list *)_mailboxListFromAddressList:(NSSet *)addresses {
	struct mailimf_mailbox_list *imfList = mailimf_mailbox_list_new_empty();
	NSEnumerator *objEnum = [addresses objectEnumerator];
	CTCoreAddress *address;
	int err;
	const char *addressName;
	const char *addressEmail;

	while(address = [objEnum nextObject]) {
		addressName = [[address name] cStringUsingEncoding:NSASCIIStringEncoding];
		addressEmail = [[address email] cStringUsingEncoding:NSASCIIStringEncoding];
		err =  mailimf_mailbox_list_add_mb(imfList, strdup(addressName), strdup(addressEmail));
		assert(err == 0);
	}
	return imfList;	
}


- (NSSet *)_addressListFromIMFAddressList:(struct mailimf_address_list *)imfList {
	clist *list;
	clistiter * iter;
	struct mailimf_address *address;
	NSMutableSet *addressSet = [NSMutableSet set];
	
	if (imfList == NULL)
		return addressSet;
		
	list = imfList->ad_list;
	for(iter = clist_begin(list); iter != NULL; iter = clist_next(iter)) {
    	address = clist_content(iter);
		/* Check to see if it's a solo address a group */
		if (address->ad_type == MAILIMF_ADDRESS_MAILBOX) {
			[addressSet addObject:[self _addressFromMailbox:address->ad_data.ad_mailbox]];
		}
		else {
			if (address->ad_data.ad_group->grp_mb_list != NULL)
				[addressSet unionSet:[self _addressListFromMailboxList:address->ad_data.ad_group->grp_mb_list]];
		}
  	}
	return addressSet;
}


- (struct mailimf_address_list *)_IMFAddressListFromAddresssList:(NSSet *)addresses {
	struct mailimf_address_list *imfList = mailimf_address_list_new_empty();
	
	NSEnumerator *objEnum = [addresses objectEnumerator];
	CTCoreAddress *address;
	int err;
	const char *addressName;
	const char *addressEmail;

	while(address = [objEnum nextObject]) {
		addressName = [[address name] cStringUsingEncoding:NSASCIIStringEncoding];
		addressEmail = [[address email] cStringUsingEncoding:NSASCIIStringEncoding];
		err =  mailimf_address_list_add_mb(imfList, strdup(addressName), strdup(addressEmail));
		assert(err == 0);
	}
	return imfList;
}
@end
