#!/usr/bin/env python3
"""
Sample Data Creation Script for Telangana Congress App
This script creates sample data for testing the API endpoints
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from app.models import User, UserRole, NewsItem, Event, MediaItem, Document
from datetime import datetime, timedelta
import uuid
import json

def create_sample_data():
    """Create sample data for testing"""
    app = create_app()
    
    with app.app_context():
        # Create tables if they don't exist
        db.create_all()
        
        print("🗄️  Creating sample data...")
        
        # Create sample users
        users_data = [
            {
                'phone': '9876543210',
                'name': 'Test User 1',
                'role': UserRole.PUBLIC,
                'region': 'Hyderabad'
            },
            {
                'phone': '9876543211',
                'name': 'Test User 2',
                'role': UserRole.CADRE,
                'region': 'Warangal'
            },
            {
                'phone': '9876543212',
                'name': 'Admin User',
                'role': UserRole.ADMIN,
                'region': 'Hyderabad'
            }
        ]
        
        for user_data in users_data:
            existing_user = User.query.filter_by(phone=user_data['phone']).first()
            if not existing_user:
                user = User(
                    id=str(uuid.uuid4()),
                    phone=user_data['phone'],
                    name=user_data['name'],
                    role=user_data['role'],
                    region=user_data['region']
                )
                db.session.add(user)
                print(f"✅ Created user: {user_data['name']} ({user_data['phone']})")
        
        # Create sample news
        news_data = [
            {
                'title_en': 'Welcome to Telangana Congress App',
                'title_te': 'తెలంగాణ కాంగ్రెస్ అనువర్తనానికి స్వాగతం',
                'description_en': 'Stay updated with the latest news and events from Telangana Congress. This app provides real-time updates about party activities, events, and important announcements.',
                'description_te': 'తెలంగాణ కాంగ్రెస్ నుండి తాజా వార్తలు మరియు కార్యక్రమాలతో నవీకరించబడండి. ఈ అనువర్తనం పార్టీ కార్యకలాపాలు, కార్యక్రమాలు మరియు ముఖ్య ప్రకటనల గురించి రియల్-టైమ్ నవీకరణలను అందిస్తుంది.',
                'category': 'General',
                'is_published': True
            },
            {
                'title_en': 'Congress Rally in Hyderabad',
                'title_te': 'హైదరాబాద్లో కాంగ్రెస్ ర్యాలీ',
                'description_en': 'Join us for a grand rally in Hyderabad to support our party candidates and discuss important issues affecting our state.',
                'description_te': 'మా పార్టీ అభ్యర్థులకు మద్దతు ఇవ్వడానికి మరియు మా రాష్ట్రాన్ని ప్రభావితం చేసే ముఖ్య సమస్యలను చర్చించడానికి హైదరాబాద్లో గ్రాండ్ ర్యాలీలో మాతో చేరండి.',
                'category': 'Events',
                'is_published': True
            },
            {
                'title_en': 'Digital India Initiative',
                'title_te': 'డిజిటల్ ఇండియా చొరవ',
                'description_en': 'Learn about our commitment to digital transformation and how we plan to bring technology to every corner of Telangana.',
                'description_te': 'డిజిటల్ రూపాంతరం పట్ల మా నిబద్ధత గురించి మరియు తెలంగాణ ప్రతి మూలకు సాంకేతికతను ఎలా తీసుకురావాలనే దాని గురించి తెలుసుకోండి.',
                'category': 'Technology',
                'is_published': True
            }
        ]
        
        for news_item_data in news_data:
            existing_news = NewsItem.query.filter_by(title_en=news_item_data['title_en']).first()
            if not existing_news:
                news_item = NewsItem(
                    id=str(uuid.uuid4()),
                    title_en=news_item_data['title_en'],
                    title_te=news_item_data['title_te'],
                    description_en=news_item_data['description_en'],
                    description_te=news_item_data['description_te'],
                    category=news_item_data['category'],
                    is_published=news_item_data['is_published']
                )
                db.session.add(news_item)
                print(f"✅ Created news: {news_item_data['title_en']}")
        
        # Create sample events
        events_data = [
            {
                'title_en': 'Congress Rally in Hyderabad',
                'title_te': 'హైదరాబాద్లో కాంగ్రెస్ ర్యాలీ',
                'description_en': 'Join us for a grand rally in Hyderabad to support our party candidates.',
                'description_te': 'మా పార్టీ అభ్యర్థులకు మద్దతు ఇవ్వడానికి హైదరాబాద్లో గ్రాండ్ ర్యాలీలో మాతో చేరండి.',
                'event_date': datetime.utcnow() + timedelta(days=7),
                'event_time': '10:00 AM',
                'location_en': 'Hyderabad, Telangana',
                'location_te': 'హైదరాబాద్, తెలంగాణ',
                'is_published': True
            },
            {
                'title_en': 'Youth Congress Meeting',
                'title_te': 'యూత్ కాంగ్రెస్ సమావేశం',
                'description_en': 'Monthly meeting of Youth Congress members to discuss upcoming activities.',
                'description_te': 'రాబోయే కార్యకలాపాలను చర్చించడానికి యూత్ కాంగ్రెస్ సభ్యుల నెలవారీ సమావేశం.',
                'event_date': datetime.utcnow() + timedelta(days=14),
                'event_time': '2:00 PM',
                'location_en': 'Warangal, Telangana',
                'location_te': 'వరంగల్, తెలంగాణ',
                'is_published': True
            }
        ]
        
        for event_data in events_data:
            existing_event = Event.query.filter_by(title_en=event_data['title_en']).first()
            if not existing_event:
                event = Event(
                    id=str(uuid.uuid4()),
                    title_en=event_data['title_en'],
                    title_te=event_data['title_te'],
                    description_en=event_data['description_en'],
                    description_te=event_data['description_te'],
                    event_date=event_data['event_date'],
                    event_time=event_data['event_time'],
                    location_en=event_data['location_en'],
                    location_te=event_data['location_te'],
                    is_published=event_data['is_published']
                )
                db.session.add(event)
                print(f"✅ Created event: {event_data['title_en']}")
        
        # Create sample media
        media_data = [
            {
                'type': 'photo',
                'url': 'https://via.placeholder.com/800x600/0066CC/FFFFFF?text=Congress+Rally',
                'thumbnail_url': 'https://via.placeholder.com/300x200/0066CC/FFFFFF?text=Rally',
                'title_en': 'Congress Rally Photos',
                'title_te': 'కాంగ్రెస్ ర్యాలీ ఫోటోలు',
                'is_published': True
            },
            {
                'type': 'video',
                'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                'thumbnail_url': 'https://via.placeholder.com/300x200/CC0000/FFFFFF?text=Video',
                'title_en': 'Party Meeting Video',
                'title_te': 'పార్టీ సమావేశ వీడియో',
                'is_published': True
            }
        ]
        
        for media_data_item in media_data:
            existing_media = MediaItem.query.filter_by(title_en=media_data_item['title_en']).first()
            if not existing_media:
                media_item = MediaItem(
                    id=str(uuid.uuid4()),
                    type=media_data_item['type'],
                    url=media_data_item['url'],
                    thumbnail_url=media_data_item['thumbnail_url'],
                    title_en=media_data_item['title_en'],
                    title_te=media_data_item['title_te'],
                    is_published=media_data_item['is_published']
                )
                db.session.add(media_item)
                print(f"✅ Created media: {media_data_item['title_en']}")
        
        # Create sample documents
        documents_data = [
            {
                'title_en': 'Party Constitution',
                'title_te': 'పార్టీ రాజ్యాంగం',
                'category': 'Official',
                'file_url': 'https://example.com/constitution.pdf',
                'access_level': json.dumps(['public', 'cadre', 'admin']),
                'is_published': True
            },
            {
                'title_en': 'Internal Guidelines',
                'title_te': 'అంతర్గత మార్గదర్శకాలు',
                'category': 'Internal',
                'file_url': 'https://example.com/guidelines.pdf',
                'access_level': json.dumps(['cadre', 'admin']),
                'is_published': True
            }
        ]
        
        for doc_data in documents_data:
            existing_doc = Document.query.filter_by(title_en=doc_data['title_en']).first()
            if not existing_doc:
                document = Document(
                    id=str(uuid.uuid4()),
                    title_en=doc_data['title_en'],
                    title_te=doc_data['title_te'],
                    category=doc_data['category'],
                    file_url=doc_data['file_url'],
                    access_level=doc_data['access_level'],
                    is_published=doc_data['is_published']
                )
                db.session.add(document)
                print(f"✅ Created document: {doc_data['title_en']}")
        
        # Commit all changes
        db.session.commit()
        
        print("\n🎉 Sample data creation completed!")
        print(f"📊 Created:")
        print(f"   - {User.query.count()} users")
        print(f"   - {NewsItem.query.count()} news items")
        print(f"   - {Event.query.count()} events")
        print(f"   - {MediaItem.query.count()} media items")
        print(f"   - {Document.query.count()} documents")
        
        print("\n🧪 Test the API with:")
        print("   - Phone: 9876543210")
        print("   - OTP: Any 6-digit number")
        print("   - API Documentation: http://localhost:80/docs/")
        print("   - Health Check: http://localhost:80/api/health")

if __name__ == "__main__":
    create_sample_data()
