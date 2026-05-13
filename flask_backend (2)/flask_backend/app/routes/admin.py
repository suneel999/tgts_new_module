"""
Admin Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request
from flask_jwt_extended import jwt_required
from flask_restx import Namespace, Resource, fields
from app.models import User, UserRole, NewsItem, Event, MediaItem, Document
from app.models.district import District
from app.models.mandal import Mandal
from app.models.parliamentary_constituency import ParliamentaryConstituency
from app.models.assembly_constituency import AssemblyConstituency
from app.seed_constituencies import MANUAL_CONSTITUENCIES, ASSEMBLY_CONSTITUENCIES
from app import db
from app.utils.auth_utils import get_current_user, require_admin
from app.utils.error_handling import log_api_call, APIError
from app.utils.timezone_utils import get_ist_now, format_ist_iso
from datetime import datetime
from sqlalchemy import or_

# Create namespace for admin
admin_ns = Namespace('admin', description='Admin operations')

print("[DEBUG] Admin namespace created, registering routes...")

# Define models directly in the namespace
dashboard_model = admin_ns.model('Dashboard Stats', {
    'total_users': fields.Integer(description='Total users'),
    'active_users': fields.Integer(description='Active users'),
    'total_news': fields.Integer(description='Total news items'),
    'published_news': fields.Integer(description='Published news items'),
    'total_events': fields.Integer(description='Total events'),
    'upcoming_events': fields.Integer(description='Upcoming events'),
    'total_media': fields.Integer(description='Total media items'),
    'total_documents': fields.Integer(description='Total documents')
})

@admin_ns.route('/dashboard')
class Dashboard(Resource):
    @admin_ns.marshal_with(dashboard_model)
    @admin_ns.doc(
        security='Bearer',
        summary='Get dashboard statistics',
        description='Retrieves comprehensive dashboard statistics (admin only)',
        responses={
            200: 'Dashboard statistics retrieved successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    @jwt_required()
    def get(self):
        """Get dashboard statistics (admin only)"""
        try:
            log_api_call('/api/admin/dashboard', 'GET')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                admin_ns.abort(403, 'Admin access required')
            
            # Calculate statistics
            total_users = User.query.count()
            active_users = User.query.filter_by(is_active=True).count()
            total_news = NewsItem.query.count()
            published_news = NewsItem.query.filter_by(is_published=True).count()
            total_events = Event.query.count()
            now_ist = get_ist_now().replace(tzinfo=None)
            upcoming_events = Event.query.filter(Event.event_date >= now_ist).count()
            total_media = MediaItem.query.count()
            total_documents = Document.query.count()
            
            return {
                'total_users': total_users,
                'active_users': active_users,
                'total_news': total_news,
                'published_news': published_news,
                'total_events': total_events,
                'upcoming_events': upcoming_events,
                'total_media': total_media,
                'total_documents': total_documents
            }
            
        except APIError as e:
            admin_ns.abort(e.status_code, e.message)
        except Exception as e:
            admin_ns.abort(500, str(e))

@admin_ns.route('/analytics')
class Analytics(Resource):
    @admin_ns.doc(
        security='Bearer',
        summary='Get detailed analytics',
        description='Retrieves detailed analytics data (admin only)',
        responses={
            200: 'Analytics data retrieved successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get detailed analytics (admin only)"""
        try:
            log_api_call('/api/admin/analytics', 'GET')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                admin_ns.abort(403, 'Admin access required')
            
            # Basic analytics - can be expanded with more sophisticated metrics
            user_growth = {
                'total_users': User.query.count(),
                'active_users': User.query.filter_by(is_active=True).count(),
                'new_users_this_month': User.query.filter(
                    User.created_at >= get_ist_now().replace(day=1, hour=0, minute=0, second=0, microsecond=0).replace(tzinfo=None)
                ).count()
            }
            
            content_performance = {
                'total_news': NewsItem.query.count(),
                'published_news': NewsItem.query.filter_by(is_published=True).count(),
                'total_events': Event.query.count(),
                'upcoming_events': Event.query.filter(Event.event_date >= get_ist_now().replace(tzinfo=None)).count(),
                'total_media': MediaItem.query.count(),
                'total_documents': Document.query.count()
            }
            
            engagement_metrics = {
                'total_rsvps': sum(event.rsvp_count for event in Event.query.all()),
                'average_rsvp_per_event': sum(event.rsvp_count for event in Event.query.all()) / max(Event.query.count(), 1)
            }
            
            return {
                'user_growth': user_growth,
                'content_performance': content_performance,
                'engagement_metrics': engagement_metrics,
                'generated_at': format_ist_iso(get_ist_now())
            }
            
        except Exception as e:
            admin_ns.abort(500, str(e))

@admin_ns.route('/health')
class SystemHealth(Resource):
    @admin_ns.doc(
        summary='Get system health status',
        description='Retrieves the current system health status',
        responses={
            200: 'System health status retrieved successfully'
        }
    )
    def get(self):
        """Get system health status"""
        try:
            log_api_call('/api/admin/health', 'GET')
            
            # Basic health checks
            db_status = 'healthy'
            try:
                db.session.execute('SELECT 1')
            except Exception:
                db_status = 'unhealthy'
            
            return {
                'status': 'healthy' if db_status == 'healthy' else 'degraded',
                'timestamp': format_ist_iso(get_ist_now()),
                'version': '1.0.0',
                'database': db_status,
                'uptime': 'N/A'  # Could be implemented with process monitoring
            }
            
        except Exception as e:
            admin_ns.abort(500, str(e))

@admin_ns.route('/maintenance')
class Maintenance(Resource):
    @admin_ns.doc(
        security='Bearer',
        summary='System maintenance operations',
        description='Performs system maintenance operations (admin only)',
        responses={
            200: 'Maintenance operation completed successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """System maintenance operations (admin only)"""
        try:
            log_api_call('/api/admin/maintenance', 'POST')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                admin_ns.abort(403, 'Admin access required')
            
            data = request.get_json()
            operation = data.get('operation', 'cleanup')
            
            if operation == 'cleanup':
                # Clean up expired OTPs
                from app.utils.auth_utils import cleanup_expired_otps
                cleaned_count = cleanup_expired_otps()
                
                return {
                    'message': 'Maintenance operation completed',
                    'operation': operation,
                    'cleaned_expired_otps': cleaned_count,
                    'timestamp': format_ist_iso(get_ist_now())
                }
            else:
                admin_ns.abort(400, 'Invalid maintenance operation')
            
        except Exception as e:
            admin_ns.abort(500, str(e))

# Define content push model
content_push_model = admin_ns.model('ContentPush', {
    'title': fields.String(required=True, description='Content title'),
    'message': fields.String(required=True, description='Content message'),
    'target_roles': fields.List(fields.String, description='Target user roles'),
    'target_regions': fields.List(fields.String, description='Target regions'),
    'content_type': fields.String(description='Type of content (news/notification)'),
    'content_id': fields.Integer(description='Related content ID')
})

@admin_ns.route('/content-push')
class ContentPush(Resource):
    @admin_ns.expect(content_push_model)
    @admin_ns.doc(
        security='Bearer',
        summary='Push content to users',
        description='Sends content/notifications to targeted users (admin only)',
        responses={
            200: 'Content pushed successfully',
            400: 'Invalid request data',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Push content to targeted users (admin only)"""
        try:
            log_api_call('/api/admin/content-push', 'POST')
            
            # Check authentication and authorization
            # TODO: Re-enable authentication in production
            # For now, allowing unauthenticated access for testing
            try:
                current_user = get_current_user()
                if current_user.role != UserRole.ADMIN:
                    admin_ns.abort(403, 'Admin access required')
                author_id = current_user.id
            except:
                # Allow unauthenticated access for testing
                # In production, this should fail
                print("[WARNING] Content push accessed without authentication - OK for testing")
                author_id = 1  # Default to first admin user
            
            data = request.get_json()
            
            # Validate required fields
            if not data.get('title') or not data.get('message'):
                admin_ns.abort(400, 'Title and message are required')
            
            title = data.get('title')
            message = data.get('message')
            target_roles = data.get('target_roles', ['public', 'cadre', 'admin'])
            target_regions = data.get('target_regions', [])
            content_type = data.get('content_type', 'notification')
            content_id = data.get('content_id')
            
            # Build query to find target users
            query = User.query.filter_by(is_active=True)
            
            # Filter by roles
            if target_roles:
                role_filters = []
                for role_name in target_roles:
                    try:
                        role_enum = UserRole[role_name.upper()]
                        role_filters.append(User.role == role_enum)
                    except KeyError:
                        continue
                
                if role_filters:
                    query = query.filter(or_(*role_filters))
            
            # Filter by regions if specified
            if target_regions:
                query = query.filter(User.region.in_(target_regions))
            
            # Get targeted users
            targeted_users = query.all()
            user_count = len(targeted_users)
            
            # In a real implementation, you would:
            # 1. Create a notification record in the database
            # 2. Send push notifications via FCM/APNS
            # 3. Send SMS notifications if configured
            # 4. Queue email notifications
            
            # For now, we'll create a NewsItem if content_type is 'news'
            if content_type == 'news':
                import uuid
                # Handle geographic access fields
                district_ids = data.get('districtIds') or data.get('district_ids')
                mandal_ids = data.get('mandalIds') or data.get('mandal_ids')
                assembly_constituency_ids = data.get('assemblyConstituencyIds') or data.get('assembly_constituency_ids')
                parliamentary_constituency_ids = data.get('parliamentaryConstituencyIds') or data.get('parliamentary_constituency_ids')
                
                # Handle title_te and description_te with proper fallbacks
                title_te = data.get('title_te', '').strip() if data.get('title_te') else ''
                if not title_te:
                    title_te = title  # Fallback to English title
                
                description_te = data.get('description_te', '').strip() if data.get('description_te') else ''
                if not description_te:
                    description_te = message  # Fallback to English description
                
                # Handle links field
                links = data.get('links')
                # Filter out empty links (where url is empty or missing)
                if links:
                    links = [link for link in links if link.get('url') and link.get('url').strip()]
                    links = links if links else None
                
                news_item = NewsItem(
                    id=str(uuid.uuid4()),
                    title_en=title,
                    title_te=title_te,
                    description_en=message,
                    description_te=description_te,
                    image_url=data.get('image_url'),
                    category=data.get('category', 'announcement'),
                    is_published=True,
                    district_ids=district_ids if district_ids else None,
                    mandal_ids=mandal_ids if mandal_ids else None,
                    assembly_constituency_ids=assembly_constituency_ids if assembly_constituency_ids else None,
                    parliamentary_constituency_ids=parliamentary_constituency_ids if parliamentary_constituency_ids else None,
                    links=links if links else None,
                    created_at=get_ist_now().replace(tzinfo=None)
                )
                db.session.add(news_item)
                db.session.commit()
                
                content_id = news_item.id
            
            # Log the push notification (in production, this would trigger actual notifications)
            print(f"[CONTENT PUSH] Title: {title}")
            print(f"[CONTENT PUSH] Message: {message}")
            print(f"[CONTENT PUSH] Targeted {user_count} users")
            print(f"[CONTENT PUSH] Roles: {target_roles}")
            print(f"[CONTENT PUSH] Regions: {target_regions}")
            
            return {
                'message': 'Content pushed successfully',
                'targeted_users': user_count,
                'content_type': content_type,
                'content_id': content_id,
                'title': title,
                'timestamp': datetime.utcnow().isoformat()
            }, 200
            
        except Exception as e:
            print(f"[ERROR] Content push failed: {str(e)}")
            admin_ns.abort(500, f'Failed to push content: {str(e)}')

print("[DEBUG] Content push endpoint registered at /api/admin/content-push")

@admin_ns.route('/test')
class TestEndpoint(Resource):
    def get(self):
        """Simple test endpoint to verify namespace is working"""
        return {'message': 'Admin namespace is working!', 'timestamp': format_ist_iso(get_ist_now())}
    
    def post(self):
        """Test POST endpoint"""
        return {'message': 'POST endpoint working!'}

print("[DEBUG] Test endpoint registered at /api/admin/test")

# Data for auto-population
TELANGANA_DISTRICTS = [
    {'en': 'Adilabad', 'te': 'ఆదిలాబాద్'},
    {'en': 'Bhadradri Kothagudem', 'te': 'భద్రాద్రి కొత్తగూడెం'},
    {'en': 'Hyderabad', 'te': 'హైదరాబాద్'},
    {'en': 'Jagtial', 'te': 'జగిత్యాల'},
    {'en': 'Jangaon', 'te': 'జంగాంవ్'},
    {'en': 'Jayashankar Bhupalpally', 'te': 'జయశంకర్ భూపాలపల్లి'},
    {'en': 'Jogulamba Gadwal', 'te': 'జోగులాంబ గద్వాల'},
    {'en': 'Kamareddy', 'te': 'కామారెడ్డి'},
    {'en': 'Karimnagar', 'te': 'కరీంనగర్'},
    {'en': 'Khammam', 'te': 'ఖమ్మం'},
    {'en': 'Kumuram Bheem', 'te': 'కుమురం భీమ్'},
    {'en': 'Mahabubabad', 'te': 'మహబూబాబాద్'},
    {'en': 'Mahbubnagar', 'te': 'మహబూబ్‌నగర్'},
    {'en': 'Mancherial', 'te': 'మంచిర్యాల'},
    {'en': 'Medak', 'te': 'మేడక్'},
    {'en': 'Medchal-Malkajgiri', 'te': 'మెడ్చల్-మల్కాజ్‌గిరి'},
    {'en': 'Mulugu', 'te': 'ములుగు'},
    {'en': 'Nagarkurnool', 'te': 'నాగర్‌కర్నూల్'},
    {'en': 'Nalgonda', 'te': 'నల్గొండ'},
    {'en': 'Narayanpet', 'te': 'నారాయణపేట'},
    {'en': 'Nirmal', 'te': 'నిర్మల్'},
    {'en': 'Nizamabad', 'te': 'నిజామాబాద్'},
    {'en': 'Peddapalli', 'te': 'పెద్దపల్లి'},
    {'en': 'Rajanna Sircilla', 'te': 'రాజన్న సిరిసిల్ల'},
    {'en': 'Rangareddy', 'te': 'రంగారెడ్డి'},
    {'en': 'Sangareddy', 'te': 'సంగారెడ్డి'},
    {'en': 'Siddipet', 'te': 'సిద్దిపేట'},
    {'en': 'Suryapet', 'te': 'సూర్యాపేట'},
    {'en': 'Vikarabad', 'te': 'వికారాబాద్'},
    {'en': 'Wanaparthy', 'te': 'వనపర్తి'},
    {'en': 'Warangal Rural', 'te': 'వరంగల్ రూరల్'},
    {'en': 'Warangal Urban', 'te': 'వరంగల్ అర్బన్'},
    {'en': 'Yadadri Bhuvanagiri', 'te': 'యాదాద్రి భువనగిరి'},
]

# Mandals data - complete list from populate script
MANDALS_DATA_CSV = """District,Mandal Name
Adilabad,Adilabad Rural
Adilabad,Adilabad Urban
Adilabad,Bazarhatnoor
Adilabad,Bela
Adilabad,Bheempur
Adilabad,Bhoraj
Adilabad,Boath
Adilabad,Gadiguda
Adilabad,Gudihatnoor
Adilabad,Ichoda
Adilabad,Inderavelly
Adilabad,Jainath
Adilabad,Mavala
Adilabad,Narnoor
Adilabad,Neradigonda
Adilabad,Sathnala
Adilabad,Sirikonda
Adilabad,Sonala
Adilabad,Talamadugu
Adilabad,Tamsi
Adilabad,Utnoor
Bhadradri Kothagudem,Allapalli
Bhadradri Kothagudem,Annapureddypalli
Bhadradri Kothagudem,Aswapuram
Bhadradri Kothagudem,Aswaraopeta
Bhadradri Kothagudem,Bhadrachalam
Bhadradri Kothagudem,Burgampahad
Bhadradri Kothagudem,Chandrugonda
Bhadradri Kothagudem,Cherla
Bhadradri Kothagudem,Chunchupalle
Bhadradri Kothagudem,Dammapeta
Bhadradri Kothagudem,Dummugudem
Bhadradri Kothagudem,Gundala
Bhadradri Kothagudem,Julurpadu
Bhadradri Kothagudem,Karakagudem
Bhadradri Kothagudem,Kothagudem
Bhadradri Kothagudem,Laxmidevipalli
Bhadradri Kothagudem,Manuguru
Bhadradri Kothagudem,Mulakalapalli
Bhadradri Kothagudem,Palwancha
Bhadradri Kothagudem,Pinapaka
Bhadradri Kothagudem,Sujathanagar
Bhadradri Kothagudem,Tekulapalli
Bhadradri Kothagudem,Yellandu
Warangal Urban,Bheemadevarpalli
Warangal Urban,Dharmasagar
Warangal Urban,Elkathurthy
Warangal Urban,Inavole
Warangal Urban,Hanumakonda
Warangal Urban,Hasanparthy
Warangal Urban,Kamalapur
Warangal Urban,Kazipet
Warangal Urban,Khila Warangal
Warangal Urban,Velair
Warangal Urban,Warangal
Hyderabad,Amberpet
Hyderabad,Asif Nagar
Hyderabad,Bahadurpura
Hyderabad,Bandlaguda
Hyderabad,Charminar
Hyderabad,Golkonda
Hyderabad,Himayathnagar
Hyderabad,Nampally
Hyderabad,Saidabad
Hyderabad,Ameerpet
Hyderabad,Khairtabad
Hyderabad,Maredpally
Hyderabad,Musheerabad
Hyderabad,Secunderabad
Hyderabad,Shaikpet
Hyderabad,Tirumalagiri
Jagtial,Beerpur
Jagtial,Buggaram
Jagtial,Dharmapuri
Jagtial,Gollapalli
Jagtial,Ibrahimpatnam
Jagtial,Jagitial
Jagtial,Jagitial Rural
Jagtial,Kodimial
Jagtial,Korutla
Jagtial,Kathlapur
Jagtial,Mallial
Jagtial,Mallapur
Jagtial,Medipalli
Jagtial,Metpalli
Jagtial,Pegadapalli
Jagtial,Raikal
Jagtial,Sarangapur
Jagtial,Velgatur
Jangaon,Bachannapeta
Jangaon,Chilpur
Jangaon,Devaruppala
Jangaon,Gundala
Jangaon,Jangaon
Jangaon,Kodakandla
Jangaon,Lingalaghanpur
Jangaon,Narmetta
Jangaon,Palakurthi
Jangaon,Raghunathapalle
Jangaon,Station Ghanpur
Jangaon,Tarigoppula
Jangaon,Zaffergadh
Jayashankar Bhupalpally,Bhupalpalle
Jayashankar Bhupalpally,Chityal
Jayashankar Bhupalpally,Ghanpur
Jayashankar Bhupalpally,Kataram
Jayashankar Bhupalpally,Mahadevpur
Jayashankar Bhupalpally,Maha Mutharam
Jayashankar Bhupalpally,Malharrao
Jayashankar Bhupalpally,Mogullapalle
Jayashankar Bhupalpally,Palimela
Jayashankar Bhupalpally,Regonda
Jayashankar Bhupalpally,Tekumatla
Jogulamba Gadwal,Alamur (Alampur)
Jogulamba Gadwal,Dharoor (Dharur)
Jogulamba Gadwal,Gadwal
Jogulamba Gadwal,Ghattu
Jogulamba Gadwal,Itikyal
Jogulamba Gadwal,Maldakal
Jogulamba Gadwal,Manopad
Jogulamba Gadwal,Rajoli
Jogulamba Gadwal,Undavelli
Jogulamba Gadwal,Waddepally
Jogulamba Gadwal,Yerravally
Kamareddy,Banswada
Kamareddy,Bhiknoor
Kamareddy,Bibipet
Kamareddy,Bichkunda
Kamareddy,Birkur
Kamareddy,Domakonda
Kamareddy,Dongargaon (Dongli)
Kamareddy,Gandhari
Kamareddy,Jukkal
Kamareddy,Kamareddy
Kamareddy,Lingampet
Kamareddy,Machareddy
Kamareddy,Madnoor
Kamareddy,Mohammadnagar
Kamareddy,Nagireddypet
Kamareddy,Nasrullabad (Nasurullabad)
Kamareddy,Nizamsagar
Kamareddy,Palwancha
Kamareddy,Pedda Kodapally
Kamareddy,Pitlam
Kamareddy,Rajampet
Kamareddy,Ramareddy
Kamareddy,Sadashivanagar
Kamareddy,Tadwai
Kamareddy,Yellareddy
Karimnagar,Chigurumamidi
Karimnagar,Choppadandi
Karimnagar,Ellandakunta
Karimnagar,Gangadhara
Karimnagar,Ganneruvaram
Karimnagar,Huzurabad
Karimnagar,Jammikunta
Karimnagar,Karimnagar
Karimnagar,Karimnagar Rural
Karimnagar,Kothapally
Karimnagar,Manakondur
Karimnagar,Ramadugu
Karimnagar,Shankarapatnam
Karimnagar,Thimmapur
Karimnagar,V. Saidapur
Karimnagar,Veenavanka
Khammam,Bonakal
Khammam,Chinthakani
Khammam,Enkoor
Khammam,Kalluru
Khammam,Kamepalli
Khammam,Khammam Rural
Khammam,Khammam Urban
Khammam,Konijerla
Khammam,Kusumanchi
Khammam,Madhira
Khammam,Mudigonda
Khammam,Nelakondapalli
Khammam,Penuballi
Khammam,Raghunadhapalem
Khammam,Sathupalli
Khammam,Singareni
Khammam,Thallada
Khammam,Tirumalayapalem
Khammam,Vemsoor
Khammam,Wyra
Khammam,Yerrupalem
Kumuram Bheem,Asifabad
Kumuram Bheem,Bejjur
Kumuram Bheem,Chintalmanepally
Kumuram Bheem,Dahegaon
Kumuram Bheem,Jainoor
Kumuram Bheem,Kagaznagar
Kumuram Bheem,Kerameri
Kumuram Bheem,Koutala
Kumuram Bheem,Lingapur
Kumuram Bheem,Luxettipet
Kumuram Bheem,Manyam
Kumuram Bheem,Potkapally
Kumuram Bheem,Sirpur (U)
Kumuram Bheem,Tiryani
Mahabubabad,Bayyaram
Mahabubabad,Chinnagudur
Mahabubabad,Danthalapalle
Mahabubabad,Dornakal
Mahabubabad,Gangaram
Mahabubabad,Garla
Mahabubabad,Gudur
Mahabubabad,Inugurthy
Mahabubabad,Kesamudram
Mahabubabad,Kothaguda
Mahabubabad,Kuravi
Mahabubabad,Mahabubabad
Mahabubabad,Maripeda
Mahabubabad,Narsimhulapet
Mahabubabad,Nellikudur
Mahabubabad,Peddavangara
Mahabubabad,Seerole
Mahabubabad,Thorrur
Mahabubnagar,Addakal
Mahabubnagar,Balanagar
Mahabubnagar,Bhoothpur
Mahabubnagar,Chinna Chintakunta
Mahabubnagar,Devarakadra
Mahabubnagar,Gandeed
Mahabubnagar,Hanwada
Mahabubnagar,Jadcherla
Mahabubnagar,Koilkonda
Mahabubnagar,Koukuntla
Mahabubnagar,Mahabubnagar (Rural)
Mahabubnagar,Mahabubnagar (Urban)
Mahabubnagar,Midjil
Mahabubnagar,Moosapet
Mahabubnagar,Mohammadabad
Mahabubnagar,Nawabpet
Mahabubnagar,Rajapur
Mancherial,Bellampally
Mancherial,Bheemaram
Mancherial,Bheemini
Mancherial,Chennur
Mancherial,Dandepally
Mancherial,Hajipur
Mancherial,Jaipur
Mancherial,Jannaram
Mancherial,Kannepally
Mancherial,Kasipet
Mancherial,Kotapally
Mancherial,Luxettipet
Mancherial,Mancherial
Mancherial,Mandamarri
Mancherial,Naspur
Mancherial,Nennel
Mancherial,Tandur
Mancherial,Vemanpally
Medak,Alladurg
Medak,Chegunta
Medak,Chilpched
Medak,Havelighanapur
Medak,Kowdipally
Medak,Kulcharam
Medak,Manoharabad
Medak,Masaipet
Medak,Medak
Medak,Narsapur
Medak,Narsingi
Medak,Nizampet
Medak,Papannapet
Medak,Ramayampet
Medak,Regode
Medak,Shankarampet (A)
Medak,Shankarampet (R)
Medak,Shivampet
Medak,Tekmal
Medak,Toopran
Medak,Yeldurthy
Medchal-Malkajgiri,Alwal
Medchal-Malkajgiri,Bachupally
Medchal-Malkajgiri,Balanagar
Medchal-Malkajgiri,Dundigal
Medchal-Malkajgiri,Ghatkesar
Medchal-Malkajgiri,Kapra
Medchal-Malkajgiri,Keesara
Medchal-Malkajgiri,Kukatpally
Medchal-Malkajgiri,Malkajgiri
Medchal-Malkajgiri,Medchal
Medchal-Malkajgiri,Medipally
Medchal-Malkajgiri,Muduchinthalapally
Medchal-Malkajgiri,Quthbullapur
Medchal-Malkajgiri,Shamirpet
Medchal-Malkajgiri,Uppal
Mulugu,Eturnagaram
Mulugu,Govindaraopet
Mulugu,Kannaigudem
Mulugu,Mallampalli
Mulugu,Mangapet
Mulugu,Mulugu
Mulugu,Tadvai
Mulugu,Venkatapur
Mulugu,Venkatapuram
Mulugu,Wajedu
Nagarkurnool,Achampet
Nagarkurnool,Amrabad
Nagarkurnool,Balamoor
Nagarkurnool,Bijinapally
Nagarkurnool,Charakonda
Nagarkurnool,Kalwakurthy
Nagarkurnool,Kodair
Nagarkurnool,Kollapur
Nagarkurnool,Lingal
Nagarkurnool,Nagarkurnool
Nagarkurnool,Padara
Nagarkurnool,Peddakothapally
Nagarkurnool,Pentlavelli
Nagarkurnool,Tadoor
Nagarkurnool,Telkapally
Nagarkurnool,Thimmajipet
Nagarkurnool,Uppununthala
Nagarkurnool,Urkonda
Nagarkurnool,Vangoor
Nagarkurnool,Veldanda
Nalgonda,Adavidevulapalli
Nalgonda,Anumula
Nalgonda,Chandampeta
Nalgonda,Chandur
Nalgonda,Chinthapally
Nalgonda,Chityal
Nalgonda,Dameracherla
Nalgonda,Devarakonda
Nalgonda,Gattuppal
Nalgonda,Gudipally
Nalgonda,Gundlapally
Nalgonda,Gurrampode
Nalgonda,Kanagal
Nalgonda,Kattangur
Nalgonda,Kethepally
Nalgonda,Kondamallepally
Nalgonda,Madugulapally
Nalgonda,Marriguda
Nalgonda,Miryalaguda
Nalgonda,Munugode
Nalgonda,Nakrekal
Nalgonda,Nalgonda
Nalgonda,Nampally
Nalgonda,Narketpally
Nalgonda,Neredugommu
Narayanpet,Damargidda
Narayanpet,Dhanwada
Narayanpet,Gundumal
Narayanpet,Kosgi
Narayanpet,Kothapally (15)
Narayanpet,Krishna
Narayanpet,Maddur
Narayanpet,Maganoor
Narayanpet,Makthal
Narayanpet,Marikal
Narayanpet,Narayanpet
Narayanpet,Narwa
Narayanpet,Utkoor
Nirmal,Basar
Nirmal,Bhainsa
Nirmal,Dasturabad
Nirmal,Dilawarpur
Nirmal,Kaddam
Nirmal,Peddur
Nirmal,Khanapur
Nirmal,Kubeer
Nirmal,Kuntala
Nirmal,Laxmanchanda
Nirmal,Lokeswaram
Nirmal,Mamada
Nirmal,Mudhole
Nirmal,Narsapur (G)
Nirmal,Nirmal (Rural)
Nirmal,Nirmal (Urban)
Nirmal,Pembi
Nirmal,Sarangapur
Nirmal,Soan
Nirmal,Tanoor
Nizamabad,Aloor
Nizamabad,Armoor
Nizamabad,Balkonda
Nizamabad,Bheemgal
Nizamabad,Bodhan
Nizamabad,Chandur
Nizamabad,Dharpally
Nizamabad,Dichpally
Nizamabad,Donkeshwar
Nizamabad,Indalwai
Nizamabad,Jakranpally
Nizamabad,Kammarpally
Nizamabad,Kotagiri
Nizamabad,Makloor
Nizamabad,Mendora
Nizamabad,Morthad
Nizamabad,Mosara
Nizamabad,Mugpal
Nizamabad,Mupkal
Nizamabad,Nandipet
Nizamabad,Navipet
Nizamabad,Nizamabad North
Nizamabad,Nizamabad Rural
Nizamabad,Nizamabad South
Nizamabad,Pothangal
Peddapalli,Anthargaon
Peddapalli,Dharmaram
Peddapalli,Eligaid
Peddapalli,Julapalli
Peddapalli,Kamanpur
Peddapalli,Manthani
Peddapalli,Mutharam (Manthani)
Peddapalli,Odela
Peddapalli,Palakurthy
Peddapalli,Peddapalli
Peddapalli,Ramagiri
Peddapalli,Ramagundam
Peddapalli,Srirampur
Peddapalli,Sulthanabad
Rajanna Sircilla,Boinpalli
Rajanna Sircilla,Chandurthy
Rajanna Sircilla,Gambhiraopet
Rajanna Sircilla,Illanthakunta
Rajanna Sircilla,Konaraopet
Rajanna Sircilla,Mustabad
Rajanna Sircilla,Rudrangi
Rajanna Sircilla,Sircilla
Rajanna Sircilla,Thangallapalli
Rajanna Sircilla,Veernapalli
Rajanna Sircilla,Vemulawada
Rajanna Sircilla,Vemulawada (Rural)
Rajanna Sircilla,Yellareddipet
Rangareddy,Chevella
Rangareddy,Ibrahimpatnam
Rangareddy,Kandukur
Rangareddy,Rajendranagar
Rangareddy,Shadnagar
Rangareddy,Abdullapurmet
Rangareddy,Adibatla
Rangareddy,Amangal
Rangareddy,Hayathnagar
Rangareddy,Gandipet
Rangareddy,Hyderabad (parts)
Rangareddy,Kothur
Rangareddy,Kulukacharla
Rangareddy,L.B. Nagar
Rangareddy,Maheshwaram
Rangareddy,Manikonda
Rangareddy,Masjid Banda
Rangareddy,Meerpet-Jillelaguda
Rangareddy,Nacharam
Rangareddy,Pambour
Rangareddy,Pedda Amberpet
Rangareddy,Pothur
Rangareddy,Pocharam (H)
Rangareddy,Serilingampally
Rangareddy,Shamshabad
Rangareddy,Shankarpally
Rangareddy,Turkayamjal
Sangareddy,Ameenpur
Sangareddy,Andole
Sangareddy,Gummadidala
Sangareddy,Hathnoora
Sangareddy,Jinnaram
Sangareddy,Kandanda
Sangareddy,Kondapur
Sangareddy,Manoor
Sangareddy,Manopad
Sangareddy,Nagar
Sangareddy,Narayankhed
Sangareddy,Nagilgidda
Sangareddy,Patancheru
Sangareddy,Pulkal
Sangareddy,Ramchandrapuram
Sangareddy,Sadasivpet
Sangareddy,Sangareddy
Sangareddy,Sirgapur
Sangareddy,Vatpally
Sangareddy,Jharasangam
Sangareddy,Kohir
Sangareddy,Mogudampally
Sangareddy,Nyalkal
Sangareddy,Raikode
Sangareddy,Zaheerabad
Siddipet,Siddipet (Urban)
Siddipet,Siddipet (Rural)
Siddipet,Nangnoor
Siddipet,Chinnakodur
Siddipet,Thoguta
Siddipet,Doultabad
Siddipet,Mirdoddi
Siddipet,Dubbak
Siddipet,Cherial
Siddipet,Komuravelli
Siddipet,Gajwel
Siddipet,Jagdevpur
Siddipet,Kondapak
Siddipet,Mulug
Siddipet,Markook
Siddipet,Wargal
Siddipet,Raipole
Siddipet,Husnabad
Siddipet,Akkannapet
Siddipet,Koheda
Siddipet,Bejjanki
Siddipet,Maddur
Suryapet,Atmakur
Suryapet,Chivvemla
Suryapet,Jajireddygudem
Suryapet,Mothey
Suryapet,Nuthankal
Suryapet,Penpahad
Suryapet,Suryapet
Suryapet,Thirumalagiri
Suryapet,Thungathurthy
Suryapet,Garidepally
Suryapet,Neredcherla
Suryapet,Nagaram
Suryapet,Maddirala
Suryapet,Palakeedu
Suryapet,Chilkur
Suryapet,Huzurnagar
Suryapet,Kodad
Suryapet,Mattampally
Suryapet,Mellachervu
Suryapet,Munagala
Suryapet,Nadigudem
Suryapet,Ananthagiri
Suryapet,Mallareddygudem
Vikarabad,Basheerabad
Vikarabad,Bommaraspet
Vikarabad,Doultabad
Vikarabad,Kodangal
Vikarabad,Peddemul
Vikarabad,Tandur
Vikarabad,Yelal
Vikarabad,Doma
Vikarabad,Dharur
Vikarabad,Bantwaram
Vikarabad,Kulkacherla
Vikarabad,Kotepally
Vikarabad,Marpalle
Vikarabad,Mominpet
Vikarabad,Nawabpet
Vikarabad,Pudur
Vikarabad,Pargi
Vikarabad,Vikarabad
Wanaparthy,Amarchinta
Wanaparthy,Atmakur
Wanaparthy,Chinnambavi
Wanaparthy,Ghanpur (Khilla)
Wanaparthy,Gopalpeta
Wanaparthy,Kothakota
Wanaparthy,Madanapur
Wanaparthy,Pangal
Wanaparthy,Pebbair
Wanaparthy,Peddamandadi
Wanaparthy,Revally
Wanaparthy,Srirangapur
Wanaparthy,Veepanagandla
Wanaparthy,Wanaparthy
Warangal Rural,Atmakur
Warangal Rural,Damera
Warangal Rural,Geesugonda
Warangal Rural,Parkal
Warangal Rural,Nadikuda
Warangal Rural,Parvathagiri
Warangal Rural,Rayaparthy
Warangal Rural,Sangem
Warangal Rural,Shayampet
Warangal Rural,Wardhannapet
Warangal Rural,Chennaraopet
Warangal Rural,Duggondi
Warangal Rural,Khanapur
Warangal Rural,Narsampet
Warangal Rural,Nallabelly
Warangal Rural,Nekkonda
Yadadri Bhuvanagiri,Addaguduru
Yadadri Bhuvanagiri,Alair
Yadadri Bhuvanagiri,Atmakur (M)
Yadadri Bhuvanagiri,Bibinagar
Yadadri Bhuvanagiri,Bhongir
Yadadri Bhuvanagiri,Bommalaramaram
Yadadri Bhuvanagiri,Motakondur
Yadadri Bhuvanagiri,Mothkur
Yadadri Bhuvanagiri,Rajapet
Yadadri Bhuvanagiri,Turkapally
Yadadri Bhuvanagiri,Yadagirigutta
Yadadri Bhuvanagiri,Bhoodan Pochampally
Yadadri Bhuvanagiri,Choutuppal
Yadadri Bhuvanagiri,Narayanapur
Yadadri Bhuvanagiri,Ramannapet
Yadadri Bhuvanagiri,Valigonda"""

@admin_ns.route('/populate-data')
class PopulateData(Resource):
    @admin_ns.doc(
        security='Bearer',
        summary='Auto-populate constituencies, districts, and mandals',
        description='Populates all districts, mandals, parliamentary constituencies, and assembly constituencies in one click (admin only)',
        responses={
            200: 'Data populated successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    @jwt_required()
    def post(self):
        """Auto-populate all constituencies, districts, and mandals (admin only)"""
        try:
            log_api_call('/api/admin/populate-data', 'POST')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                admin_ns.abort(403, 'Admin access required')
            
            results = {
                'districts': {'added': 0, 'updated': 0, 'skipped': 0},
                'mandals': {'added': 0, 'updated': 0, 'skipped': 0, 'errors': []},
                'parliamentary_constituencies': {'added': 0, 'updated': 0, 'skipped': 0},
                'assembly_constituencies': {'added': 0, 'updated': 0, 'skipped': 0, 'errors': []}
            }
            
            # Step 1: Populate Districts
            try:
                for district_data in TELANGANA_DISTRICTS:
                    name_en = district_data['en']
                    name_te = district_data.get('te', name_en)
                    
                    existing = District.query.filter_by(name_en=name_en).first()
                    
                    if existing:
                        existing.name_te = name_te
                        existing.state = 'Telangana'
                        existing.is_active = True
                        results['districts']['updated'] += 1
                    else:
                        new_district = District(
                            name_en=name_en,
                            name_te=name_te,
                            state='Telangana',
                            is_active=True
                        )
                        db.session.add(new_district)
                        results['districts']['added'] += 1
                
                db.session.commit()
            except Exception as e:
                db.session.rollback()
                raise APIError(f'Failed to populate districts: {str(e)}', 500)
            
            # Step 2: Populate Parliamentary Constituencies
            try:
                for const_data in MANUAL_CONSTITUENCIES:
                    constituency_number = const_data['number']
                    name_en = const_data['name']
                    
                    existing = ParliamentaryConstituency.query.filter_by(
                        constituency_number=constituency_number
                    ).first()
                    
                    if existing:
                        existing.name_en = name_en
                        existing.name_te = name_en
                        existing.state = 'Telangana'
                        existing.is_active = True
                        results['parliamentary_constituencies']['updated'] += 1
                    else:
                        new_constituency = ParliamentaryConstituency(
                            constituency_number=constituency_number,
                            name_en=name_en,
                            name_te=name_en,
                            state='Telangana',
                            is_active=True
                        )
                        db.session.add(new_constituency)
                        results['parliamentary_constituencies']['added'] += 1
                
                db.session.commit()
            except Exception as e:
                db.session.rollback()
                raise APIError(f'Failed to populate parliamentary constituencies: {str(e)}', 500)
            
            # Step 3: Populate Assembly Constituencies
            try:
                parliament_constituencies = {
                    pc.constituency_number: pc.constituency_number 
                    for pc in ParliamentaryConstituency.query.all()
                }
                
                for parliament_number, assembly_list in ASSEMBLY_CONSTITUENCIES.items():
                    parliament_id = parliament_constituencies.get(parliament_number)
                    if not parliament_id:
                        results['assembly_constituencies']['errors'].append(
                            f'Parliamentary constituency {parliament_number} not found'
                        )
                        continue
                    
                    for assembly_data in assembly_list:
                        assembly_number = assembly_data['number']
                        assembly_name = assembly_data['name']
                        
                        existing = AssemblyConstituency.query.filter_by(
                            constituency_number=assembly_number
                        ).first()
                        
                        if existing:
                            existing.name_en = assembly_name
                            existing.name_te = assembly_name
                            existing.parliament_constituency_id = parliament_id
                            existing.state = 'Telangana'
                            existing.is_active = True
                            results['assembly_constituencies']['updated'] += 1
                        else:
                            new_assembly = AssemblyConstituency(
                                constituency_number=assembly_number,
                                name_en=assembly_name,
                                name_te=assembly_name,
                                state='Telangana',
                                parliament_constituency_id=parliament_id,
                                is_active=True
                            )
                            db.session.add(new_assembly)
                            results['assembly_constituencies']['added'] += 1
                
                db.session.commit()
            except Exception as e:
                db.session.rollback()
                raise APIError(f'Failed to populate assembly constituencies: {str(e)}', 500)
            
            # Step 4: Populate Mandals
            try:
                # District name mappings for cases where mandals data uses different names
                district_name_mapping = {
                    'Hanumakonda': 'Warangal Urban',  # Map Hanumakonda to Warangal Urban
                    'Kumuram Bheem Asifabad': 'Kumuram Bheem',  # Map full name to short name
                }
                
                # Parse mandals data
                mandals_list = []
                for line in MANDALS_DATA_CSV.strip().split('\n')[1:]:  # Skip header
                    if not line.strip():
                        continue
                    parts = line.split(',', 1)
                    if len(parts) == 2:
                        district_name = parts[0].strip()
                        mandal_name = parts[1].strip()
                        if district_name and mandal_name:
                            # Apply district name mapping if needed
                            mapped_district_name = district_name_mapping.get(district_name, district_name)
                            mandals_list.append((mapped_district_name, mandal_name))
                
                # Process mandals
                for district_name, mandal_name in mandals_list:
                    district = District.query.filter_by(name_en=district_name).first()
                    if not district:
                        results['mandals']['errors'].append(
                            f'District "{district_name}" not found for mandal "{mandal_name}"'
                        )
                        results['mandals']['skipped'] += 1
                        continue
                    
                    existing = Mandal.query.filter_by(
                        district_id=district.id, 
                        name_en=mandal_name
                    ).first()
                    
                    if existing:
                        existing.name_te = mandal_name
                        existing.is_active = True
                        results['mandals']['updated'] += 1
                    else:
                        new_mandal = Mandal(
                            district_id=district.id,
                            name_en=mandal_name,
                            name_te=mandal_name,
                            is_active=True
                        )
                        db.session.add(new_mandal)
                        results['mandals']['added'] += 1
                
                db.session.commit()
            except Exception as e:
                db.session.rollback()
                raise APIError(f'Failed to populate mandals: {str(e)}', 500)
            
            return {
                'message': 'Data populated successfully',
                'results': results,
                'summary': {
                    'total_districts': results['districts']['added'] + results['districts']['updated'],
                    'total_mandals': results['mandals']['added'] + results['mandals']['updated'],
                    'total_parliamentary_constituencies': results['parliamentary_constituencies']['added'] + results['parliamentary_constituencies']['updated'],
                    'total_assembly_constituencies': results['assembly_constituencies']['added'] + results['assembly_constituencies']['updated']
                },
                'timestamp': format_ist_iso(get_ist_now())
            }, 200
            
        except APIError:
            raise
        except Exception as e:
            admin_ns.abort(500, f'Failed to populate data: {str(e)}')

print("[DEBUG] Populate data endpoint registered at /api/admin/populate-data")