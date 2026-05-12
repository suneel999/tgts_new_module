#!/usr/bin/env python3
"""
Production WSGI Configuration for Telangana Congress Communication App
Gunicorn configuration for production deployment
"""

import os
import multiprocessing
from app import create_app

# Create Flask application
application = create_app()

# Gunicorn configuration
bind = f"0.0.0.0:{os.getenv('PORT', 80)}"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
preload_app = True

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Security
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

# Process naming
proc_name = "telangana-congress-api"

# SSL (if using HTTPS)
# keyfile = "/path/to/keyfile"
# certfile = "/path/to/certfile"

if __name__ == "__main__":
    application.run(host="0.0.0.0", port=int(os.getenv("PORT", 80)))


