"""
Push Notification Service
Handles sending push notifications via FCM (Firebase Cloud Messaging)
"""

import requests
import json
import logging
from flask import current_app
from app.models import User, UserRole

logger = logging.getLogger(__name__)

class PushNotificationService:
    """Service for sending push notifications"""
    
    def __init__(self):
        try:
            self.fcm_server_key = current_app.config.get('FCM_SERVER_KEY')
            self.fcm_api_url = current_app.config.get('FCM_API_URL', 'https://fcm.googleapis.com/fcm/send')
        except RuntimeError:
            # No Flask app context - will be None, notifications won't work
            logger.warning("No Flask app context for push notification service")
            self.fcm_server_key = None
            self.fcm_api_url = 'https://fcm.googleapis.com/fcm/send'
    
    def send_notification(self, title, message, data=None, target_users=None):
        """
        Send push notification to users
        
        Args:
            title: Notification title
            message: Notification message
            data: Additional data payload
            target_users: List of user IDs to target (None = all active users)
        
        Returns:
            dict: Result with success status and details
        """
        try:
            # Get target user FCM tokens
            if target_users is None:
                # Get all active users with FCM tokens
                users = User.query.filter_by(is_active=True).filter(User.fcm_token != None).all()
            else:
                users = User.query.filter(
                    User.id.in_(target_users),
                    User.is_active == True,
                    User.fcm_token != None
                ).all()
            
            if not users:
                logger.warning("No users with FCM tokens found")
                return {
                    'success': False,
                    'message': 'No users with FCM tokens found',
                    'count': 0
                }
            
            # Send notification to each user
            success_count = 0
            failed_count = 0
            
            for user in users:
                result = self._send_to_token(
                    token=user.fcm_token,
                    title=title,
                    message=message,
                    data=data
                )
                
                if result['success']:
                    success_count += 1
                else:
                    failed_count += 1
            
            logger.info(f"Notifications sent: {success_count} successful, {failed_count} failed")
            
            return {
                'success': True,
                'message': f'Sent {success_count} notifications',
                'success_count': success_count,
                'failed_count': failed_count,
                'total': len(users)
            }
            
        except Exception as e:
            logger.error(f"Error sending notifications: {str(e)}")
            return {
                'success': False,
                'message': f'Error sending notifications: {str(e)}',
                'count': 0
            }
    
    def _send_to_token(self, token, title, message, data=None):
        """Send notification to a specific FCM token"""
        try:
            if not self.fcm_server_key:
                logger.warning("FCM server key not configured, notification not sent")
                return {
                    'success': False,
                    'message': 'FCM not configured'
                }
            
            headers = {
                'Authorization': f'key={self.fcm_server_key}',
                'Content-Type': 'application/json'
            }
            
            payload = {
                'to': token,
                'notification': {
                    'title': title,
                    'body': message,
                    'sound': 'default',
                    'badge': '1'
                }
            }
            
            if data:
                payload['data'] = data
            
            response = requests.post(
                self.fcm_api_url,
                headers=headers,
                data=json.dumps(payload),
                timeout=10
            )
            
            if response.status_code == 200:
                logger.info(f"Notification sent successfully to token")
                return {'success': True}
            else:
                logger.error(f"Failed to send notification: {response.text}")
                return {
                    'success': False,
                    'message': f'HTTP {response.status_code}: {response.text}'
                }
                
        except Exception as e:
            logger.error(f"Error sending notification to token: {str(e)}")
            return {
                'success': False,
                'message': str(e)
            }
    
    def send_media_upload_notification(self, media_type, title_te):
        """Send notification when new media is uploaded"""
        title = f"New {media_type.capitalize()} Available"
        message = title_te if title_te else f"Check out the new {media_type}!"
        
        data = {
            'type': 'media_upload',
            'media_type': media_type
        }
        
        return self.send_notification(title, message, data)

# Global instance - lazy initialization
_push_notification_service_instance = None

def get_push_notification_service():
    """Get or create push notification service instance with proper Flask context"""
    # Always create fresh instance to ensure proper Flask app context
    return PushNotificationService()

# For backward compatibility
push_notification_service = None  # Will be initialized lazily

