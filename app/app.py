#!/usr/bin/env python3
"""
Simple Python Flask application for DevOps playground demo.
This app demonstrates a basic web service with database connectivity.
"""

import os
import logging
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor
import redis
from datetime import datetime
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment variables
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'demo_db')
DB_USER = os.getenv('DB_USER', 'demo_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'demo_password')

REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', '')

# Initialize Redis connection
try:
    redis_client = redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        password=REDIS_PASSWORD if REDIS_PASSWORD else None,
        decode_responses=True
    )
    redis_client.ping()
    logger.info("Connected to Redis successfully")
except Exception as e:
    logger.error(f"Failed to connect to Redis: {e}")
    redis_client = None

def get_db_connection():
    """Get database connection"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return None

def init_database():
    """Initialize database tables"""
    conn = get_db_connection()
    if not conn:
        return False
    
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    email VARCHAR(100) UNIQUE NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS visits (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER REFERENCES users(id),
                    page VARCHAR(100),
                    visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            conn.commit()
            logger.info("Database tables initialized successfully")
            return True
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        return False
    finally:
        conn.close()

@app.route('/')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })

@app.route('/health')
def detailed_health():
    """Detailed health check with database and Redis status"""
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0',
        'services': {}
    }
    
    # Check database connection
    db_conn = get_db_connection()
    if db_conn:
        health_status['services']['database'] = 'healthy'
        db_conn.close()
    else:
        health_status['services']['database'] = 'unhealthy'
        health_status['status'] = 'degraded'
    
    # Check Redis connection
    if redis_client:
        try:
            redis_client.ping()
            health_status['services']['redis'] = 'healthy'
        except:
            health_status['services']['redis'] = 'unhealthy'
            health_status['status'] = 'degraded'
    else:
        health_status['services']['redis'] = 'unhealthy'
        health_status['status'] = 'degraded'
    
    return jsonify(health_status)

@app.route('/users', methods=['GET'])
def get_users():
    """Get all users"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("SELECT * FROM users ORDER BY created_at DESC")
            users = cursor.fetchall()
            return jsonify([dict(user) for user in users])
    except Exception as e:
        logger.error(f"Error fetching users: {e}")
        return jsonify({'error': 'Failed to fetch users'}), 500
    finally:
        conn.close()

@app.route('/users', methods=['POST'])
def create_user():
    """Create a new user"""
    data = request.get_json()
    if not data or 'name' not in data or 'email' not in data:
        return jsonify({'error': 'Name and email are required'}), 400
    
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id",
                (data['name'], data['email'])
            )
            user_id = cursor.fetchone()[0]
            conn.commit()
            
            # Cache user data in Redis
            if redis_client:
                try:
                    user_data = {
                        'id': user_id,
                        'name': data['name'],
                        'email': data['email'],
                        'created_at': datetime.utcnow().isoformat()
                    }
                    redis_client.setex(f"user:{user_id}", 3600, json.dumps(user_data))
                except Exception as e:
                    logger.warning(f"Failed to cache user in Redis: {e}")
            
            return jsonify({
                'id': user_id,
                'name': data['name'],
                'email': data['email'],
                'message': 'User created successfully'
            }), 201
    except psycopg2.IntegrityError:
        return jsonify({'error': 'Email already exists'}), 409
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        return jsonify({'error': 'Failed to create user'}), 500
    finally:
        conn.close()

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user"""
    # Try Redis cache first
    if redis_client:
        try:
            cached_user = redis_client.get(f"user:{user_id}")
            if cached_user:
                return jsonify(json.loads(cached_user))
        except Exception as e:
            logger.warning(f"Failed to get user from Redis cache: {e}")
    
    # Fallback to database
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
            user = cursor.fetchone()
            if user:
                return jsonify(dict(user))
            else:
                return jsonify({'error': 'User not found'}), 404
    except Exception as e:
        logger.error(f"Error fetching user: {e}")
        return jsonify({'error': 'Failed to fetch user'}), 500
    finally:
        conn.close()

@app.route('/metrics')
def metrics():
    """Simple metrics endpoint for Prometheus"""
    metrics_data = {
        'http_requests_total': 1,
        'http_request_duration_seconds': 0.1,
        'database_connections_active': 1 if get_db_connection() else 0,
        'redis_connections_active': 1 if redis_client and redis_client.ping() else 0
    }
    
    # Format as Prometheus metrics
    prometheus_metrics = []
    for metric, value in metrics_data.items():
        prometheus_metrics.append(f"{metric} {value}")
    
    return '\n'.join(prometheus_metrics), 200, {'Content-Type': 'text/plain'}

if __name__ == '__main__':
    # Initialize database on startup
    if init_database():
        logger.info("Database initialized successfully")
    else:
        logger.error("Failed to initialize database")
    
    # Start the Flask application
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
