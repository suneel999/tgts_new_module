"""
Twilio SMS Service for OTP functionality
Handles sending OTP messages via Twilio SMS API
"""

import os
import logging
from twilio.rest import Client
from twilio.base.exceptions import TwilioException
from flask import current_app

logger = logging.getLogger(__name__)

class TwilioService:
    """Service class for Twilio SMS operations"""
    
    def __init__(self):
        """Initialize Twilio client with credentials from environment"""
        self.account_sid = os.getenv('TWILIO_ACCOUNT_SID')
        self.auth_token = os.getenv('TWILIO_AUTH_TOKEN')
        self.phone_number = os.getenv('TWILIO_PHONE_NUMBER')
        
        if not all([self.account_sid, self.auth_token, self.phone_number]):
            logger.warning("Twilio credentials not configured. SMS functionality will be disabled.")
            self.client = None
        else:
            try:
                self.client = Client(self.account_sid, self.auth_token)
                logger.info("Twilio client initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Twilio client: {str(e)}")
                self.client = None
    
    def send_otp_sms(self, phone_number, otp_code):
        """
        Send OTP via SMS using Twilio
        
        Args:
            phone_number (str): Recipient phone number (should include country code)
            otp_code (str): 6-digit OTP code
            
        Returns:
            dict: Response with success status and message details
        """
        if not self.client:
            logger.error("Twilio client not initialized")
            return {
                'success': False,
                'error': 'SMS service not configured',
                'message_id': None
            }
        
        try:
            # Format phone number to E.164 format if needed
            formatted_phone = self._format_phone_number(phone_number)
            
            # Create SMS message
            message_body = f"Your Telangana Congress App OTP is: {otp_code}. This code is valid for 5 minutes. Do not share this code with anyone."
            
            # Send SMS
            message = self.client.messages.create(
                body=message_body,
                from_=self.phone_number,
                to=formatted_phone
            )
            
            logger.info(f"OTP SMS sent successfully to {formatted_phone}. Message SID: {message.sid}")
            
            return {
                'success': True,
                'message_id': message.sid,
                'phone_number': formatted_phone,
                'status': message.status
            }
            
        except TwilioException as e:
            logger.error(f"Twilio API error sending SMS to {phone_number}: {str(e)}")
            return {
                'success': False,
                'error': f'Twilio API error: {str(e)}',
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
            str: Formatted phone number in E.164 format
        """
        # Remove all non-digit characters
        digits_only = ''.join(filter(str.isdigit, phone_number))
        
        # If it's a 10-digit Indian number, add +91
        if len(digits_only) == 10:
            return f"+91{digits_only}"
        
        # If it already has country code, add + if missing
        if len(digits_only) > 10 and not phone_number.startswith('+'):
            return f"+{digits_only}"
        
        # Return as is if already properly formatted
        return phone_number
    
    def get_message_status(self, message_sid):
        """
        Get the status of a sent message
        
        Args:
            message_sid (str): Twilio message SID
            
        Returns:
            dict: Message status information
        """
        if not self.client:
            return {'error': 'Twilio client not initialized'}
        
        try:
            message = self.client.messages(message_sid).fetch()
            return {
                'sid': message.sid,
                'status': message.status,
                'to': message.to,
                'from': message.from_,
                'body': message.body,
                'date_created': message.date_created.isoformat(),
                'date_sent': message.date_sent.isoformat() if message.date_sent else None,
                'error_code': message.error_code,
                'error_message': message.error_message
            }
        except TwilioException as e:
            logger.error(f"Error fetching message status for {message_sid}: {str(e)}")
            return {'error': str(e)}
        except Exception as e:
            logger.error(f"Unexpected error fetching message status: {str(e)}")
            return {'error': str(e)}
    
    def is_configured(self):
        """
        Check if Twilio service is properly configured
        
        Returns:
            bool: True if configured, False otherwise
        """
        return self.client is not None and all([
            self.account_sid,
            self.auth_token,
            self.phone_number
        ])

# Global instance
twilio_service = TwilioService()