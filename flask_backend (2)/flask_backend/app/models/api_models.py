"""
Shared API Models for Telangana Congress Communication App
This module contains all Flask-RESTX models for consistent API documentation
"""

from flask_restx import fields

def create_shared_models(api):
    """Create shared models for the API"""
    
    # User Models
    user_model = api.model('User', {
        'id': fields.String(description='User ID'),
        'phone': fields.String(description='Phone number'),
        'name': fields.String(description='User name'),
        'role': fields.String(description='User role (public, cadre, admin)'),
        'region': fields.String(description='User region'),
        'is_active': fields.Boolean(description='User active status'),
        'created_at': fields.String(description='Creation timestamp'),
        'updated_at': fields.String(description='Last update timestamp')
    })
    
    login_model = api.model('Login', {
        'phone': fields.String(required=True, description='Phone number', example='9876543210')
    })
    
    otp_model = api.model('OTP Verification', {
        'phone': fields.String(required=True, description='Phone number', example='9876543210'),
        'otp': fields.String(required=True, description='OTP code', example='123456')
    })
    
    profile_update_model = api.model('Profile Update', {
        'name': fields.String(description='User name', example='John Doe'),
        'region': fields.String(description='User region', example='Hyderabad')
    })
    
    # News Models
    news_model = api.model('News Item', {
        'id': fields.String(description='News ID'),
        'title_en': fields.String(description='Title in English'),
        'title_te': fields.String(description='Title in Telugu'),
        'description_en': fields.String(description='Description in English'),
        'description_te': fields.String(description='Description in Telugu'),
        'image_url': fields.String(description='Image URL'),
        'category': fields.String(description='News category'),
        'is_published': fields.Boolean(description='Published status'),
        'created_at': fields.String(description='Creation timestamp'),
        'updated_at': fields.String(description='Last update timestamp')
    })
    
    news_create_model = api.model('News Create', {
        'title_en': fields.String(required=True, description='Title in English', example='Congress Rally'),
        'title_te': fields.String(required=True, description='Title in Telugu', example='కాంగ్రెస్ ర్యాలీ'),
        'description_en': fields.String(required=True, description='Description in English', example='Join us for a grand rally'),
        'description_te': fields.String(required=True, description='Description in Telugu', example='గ్రాండ్ ర్యాలీలో మాతో చేరండి'),
        'image_url': fields.String(description='Image URL', example='https://example.com/image.jpg'),
        'category': fields.String(required=True, description='News category', example='General'),
        'is_published': fields.Boolean(description='Published status', default=False)
    })
    
    # Event Models
    event_model = api.model('Event', {
        'id': fields.String(description='Event ID'),
        'title_en': fields.String(description='Title in English'),
        'title_te': fields.String(description='Title in Telugu'),
        'description_en': fields.String(description='Description in English'),
        'description_te': fields.String(description='Description in Telugu'),
        'event_date': fields.String(description='Event date'),
        'event_time': fields.String(description='Event time'),
        'location_en': fields.String(description='Location in English'),
        'location_te': fields.String(description='Location in Telugu'),
        'image_url': fields.String(description='Image URL'),
        'rsvp_count': fields.Integer(description='RSVP count'),
        'is_published': fields.Boolean(description='Published status'),
        'created_at': fields.String(description='Creation timestamp'),
        'updated_at': fields.String(description='Last update timestamp')
    })
    
    event_create_model = api.model('Event Create', {
        'title_en': fields.String(required=True, description='Title in English', example='Congress Rally'),
        'title_te': fields.String(required=True, description='Title in Telugu', example='కాంగ్రెస్ ర్యాలీ'),
        'description_en': fields.String(required=True, description='Description in English', example='Join us for a grand rally'),
        'description_te': fields.String(required=True, description='Description in Telugu', example='గ్రాండ్ ర్యాలీలో మాతో చేరండి'),
        'event_date': fields.String(required=True, description='Event date (ISO format)', example='2024-01-15'),
        'event_time': fields.String(required=True, description='Event time', example='10:00 AM'),
        'location_en': fields.String(required=True, description='Location in English', example='Hyderabad, Telangana'),
        'location_te': fields.String(required=True, description='Location in Telugu', example='హైదరాబాద్, తెలంగాణ'),
        'image_url': fields.String(description='Image URL', example='https://example.com/image.jpg'),
        'is_published': fields.Boolean(description='Published status', default=False)
    })
    
    # Media Models
    media_model = api.model('Media Item', {
        'id': fields.String(description='Media ID'),
        'type': fields.String(description='Media type (photo/video)'),
        'url': fields.String(description='Media URL'),
        'thumbnail_url': fields.String(description='Thumbnail URL'),
        'title_en': fields.String(description='Title in English'),
        'title_te': fields.String(description='Title in Telugu'),
        'is_published': fields.Boolean(description='Published status'),
        'created_at': fields.String(description='Creation timestamp'),
        'updated_at': fields.String(description='Last update timestamp')
    })
    
    media_create_model = api.model('Media Create', {
        'type': fields.String(required=True, description='Media type (photo/video)', example='photo'),
        'url': fields.String(required=True, description='Media URL', example='https://example.com/media.jpg'),
        'thumbnail_url': fields.String(description='Thumbnail URL', example='https://example.com/thumb.jpg'),
        'title_en': fields.String(required=True, description='Title in English', example='Congress Rally Photos'),
        'title_te': fields.String(required=True, description='Title in Telugu', example='కాంగ్రెస్ ర్యాలీ ఫోటోలు'),
        'is_published': fields.Boolean(description='Published status', default=False)
    })
    
    # Document Models
    document_model = api.model('Document', {
        'id': fields.String(description='Document ID'),
        'title_en': fields.String(description='Title in English'),
        'title_te': fields.String(description='Title in Telugu'),
        'category': fields.String(description='Document category'),
        'file_url': fields.String(description='File URL'),
        'access_level': fields.Raw(description='Access levels'),
        'is_published': fields.Boolean(description='Published status'),
        'created_at': fields.String(description='Creation timestamp'),
        'updated_at': fields.String(description='Last update timestamp')
    })
    
    document_create_model = api.model('Document Create', {
        'title_en': fields.String(required=True, description='Title in English', example='Party Constitution'),
        'title_te': fields.String(required=True, description='Title in Telugu', example='పార్టీ రాజ్యాంగం'),
        'category': fields.String(required=True, description='Document category', example='Official'),
        'file_url': fields.String(required=True, description='File URL', example='https://example.com/document.pdf'),
        'access_level': fields.Raw(required=True, description='Access levels (JSON array)', example=['public', 'cadre', 'admin']),
        'is_published': fields.Boolean(description='Published status', default=False)
    })
    
    # Admin Models
    dashboard_model = api.model('Dashboard Stats', {
        'total_users': fields.Integer(description='Total users'),
        'active_users': fields.Integer(description='Active users'),
        'total_news': fields.Integer(description='Total news items'),
        'published_news': fields.Integer(description='Published news items'),
        'total_events': fields.Integer(description='Total events'),
        'upcoming_events': fields.Integer(description='Upcoming events'),
        'total_media': fields.Integer(description='Total media items'),
        'total_documents': fields.Integer(description='Total documents')
    })
    
    # Common Response Models
    success_response_model = api.model('Success Response', {
        'message': fields.String(description='Success message'),
        'data': fields.Raw(description='Response data')
    })
    
    error_response_model = api.model('Error Response', {
        'error': fields.String(description='Error message'),
        'code': fields.Integer(description='Error code')
    })
    
    pagination_model = api.model('Pagination', {
        'page': fields.Integer(description='Current page'),
        'per_page': fields.Integer(description='Items per page'),
        'total': fields.Integer(description='Total items'),
        'pages': fields.Integer(description='Total pages')
    })
    
    return {
        'user_model': user_model,
        'login_model': login_model,
        'otp_model': otp_model,
        'profile_update_model': profile_update_model,
        'news_model': news_model,
        'news_create_model': news_create_model,
        'event_model': event_model,
        'event_create_model': event_create_model,
        'media_model': media_model,
        'media_create_model': media_create_model,
        'document_model': document_model,
        'document_create_model': document_create_model,
        'dashboard_model': dashboard_model,
        'success_response_model': success_response_model,
        'error_response_model': error_response_model,
        'pagination_model': pagination_model
    }

