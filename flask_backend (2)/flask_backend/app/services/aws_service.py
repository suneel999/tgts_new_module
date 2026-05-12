import os
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class SNSService:
    """Service class for AWS SNS SMS operations"""

    def __init__(self):
        """Initialize SNS client with credentials from environment or IAM role"""

        self.aws_region = os.getenv('AWS_REGION', 'ap-south-1')
        self.sender_id = os.getenv('AWS_SNS_SENDER_ID', None)   # Optional
        self.sms_type = os.getenv('AWS_SNS_SMS_TYPE', 'Transactional')  # or Promotional

        try:
            self.client = boto3.client('sns', region_name=self.aws_region)
            logger.info("AWS SNS client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize SNS client: {str(e)}")
            self.client = None


    def send_otp_sms(self, phone_number, otp_code):
        """
        Send OTP via AWS SNS

        Args:
            phone_number (str): Recipient phone number (should include country code)
            otp_code (str): 6-digit OTP code

        Returns:
            dict: Response with success status and message details
        """

        if not self.client:
            logger.error("SNS client not initialized")
            return {
                'success': False,
                'error': 'SNS service not configured',
                'message_id': None
            }

        try:
            # Format phone number to E.164
            formatted_phone = self._format_phone_number(phone_number)

            message_body = f"Your Telangana Congress App OTP is: {otp_code}. This code is valid for 5 minutes. Do not share this code with anyone."

            message_attributes = {
                'AWS.SNS.SMS.SMSType': {
                    'DataType': 'String',
                    'StringValue': self.sms_type
                }
            }

            # Add Sender ID if set (not supported in all countries)
            if self.sender_id:
                message_attributes['AWS.SNS.SMS.SenderID'] = {
                    'DataType': 'String',
                    'StringValue': self.sender_id
                }

            # Publish SMS
            response = self.client.publish(
                PhoneNumber=formatted_phone,
                Message=message_body,
                MessageAttributes=message_attributes
            )

            logger.info(f"OTP SMS sent successfully to {formatted_phone}. Message ID: {response.get('MessageId')}")

            return {
                'success': True,
                'message_id': response.get('MessageId'),
                'phone_number': formatted_phone,
                'status': 'SENT'
            }

        except ClientError as e:
            logger.error(f"AWS SNS error sending SMS to {phone_number}: {str(e)}")
            return {
                'success': False,
                'error': f'AWS SNS error: {str(e)}',
                'message_id': None
            }

        except Exception as e:
            logger.error(f"Unexpected error sending SMS to {phone_number}: {str(e)}")
            return {
                'success': False,
                'error': f'Unexpected error: {str(e)}',
                'message_id': None
            }


    def _format_phone_number(self, phone_number):
        """
        Format phone number to E.164 format

        Args:
            phone_number (str): Phone number in various formats

        Returns:
            str: Formatted phone number in E.164
        """

        digits_only = ''.join(filter(str.isdigit, phone_number))

        # If it's a 10-digit Indian number, add +91
        if len(digits_only) == 10:
            return f"+91{digits_only}"

        # If it contains country code but missing +
        if len(digits_only) > 10 and not phone_number.startswith('+'):
            return f"+{digits_only}"

        return phone_number

aws_sns = SNSService()
