#!/usr/bin/env python3
"""
Test suite for the DevOps Playground Flask application.
"""

import pytest
import json
from unittest.mock import patch, MagicMock
from app import app


@pytest.fixture
def client():
    """Create a test client for the Flask application."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_health_check(client):
    """Test the basic health check endpoint."""
    response = client.get('/')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert 'timestamp' in data
    assert data['version'] == '1.0.0'


@patch('app.get_db_connection')
def test_detailed_health_healthy(mock_db_conn, client):
    """Test the detailed health check with healthy services."""
    # Mock database connection
    mock_conn = MagicMock()
    mock_db_conn.return_value = mock_conn
    
    # Mock Redis client
    with patch('app.redis_client') as mock_redis:
        mock_redis.ping.return_value = True
        
        response = client.get('/health')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert data['status'] == 'healthy'
        assert data['services']['database'] == 'healthy'
        assert data['services']['redis'] == 'healthy'


@patch('app.get_db_connection')
def test_detailed_health_degraded(mock_db_conn, client):
    """Test the detailed health check with degraded services."""
    # Mock database connection failure
    mock_db_conn.return_value = None
    
    # Mock Redis client failure
    with patch('app.redis_client') as mock_redis:
        mock_redis.ping.side_effect = Exception("Connection failed")
        
        response = client.get('/health')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert data['status'] == 'degraded'
        assert data['services']['database'] == 'unhealthy'
        assert data['services']['redis'] == 'unhealthy'


@patch('app.get_db_connection')
def test_get_users_success(mock_db_conn, client):
    """Test getting users successfully."""
    # Mock database connection and cursor
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
    mock_cursor.fetchall.return_value = [
        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'created_at': '2023-01-01T00:00:00Z'}
    ]
    mock_db_conn.return_value = mock_conn
    
    response = client.get('/users')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert len(data) == 1
    assert data[0]['name'] == 'John Doe'
    assert data[0]['email'] == 'john@example.com'


@patch('app.get_db_connection')
def test_get_users_db_failure(mock_db_conn, client):
    """Test getting users with database failure."""
    mock_db_conn.return_value = None
    
    response = client.get('/users')
    assert response.status_code == 500
    
    data = json.loads(response.data)
    assert 'error' in data


@patch('app.get_db_connection')
def test_create_user_success(mock_db_conn, client):
    """Test creating a user successfully."""
    # Mock database connection and cursor
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
    mock_cursor.fetchone.return_value = [1]  # Return user ID
    mock_db_conn.return_value = mock_conn
    
    # Mock Redis client
    with patch('app.redis_client') as mock_redis:
        mock_redis.setex.return_value = True
        
        user_data = {
            'name': 'Jane Doe',
            'email': 'jane@example.com'
        }
        
        response = client.post('/users', 
                             data=json.dumps(user_data),
                             content_type='application/json')
        assert response.status_code == 201
        
        data = json.loads(response.data)
        assert data['name'] == 'Jane Doe'
        assert data['email'] == 'jane@example.com'
        assert data['id'] == 1


def test_create_user_missing_fields(client):
    """Test creating a user with missing fields."""
    user_data = {'name': 'John Doe'}  # Missing email
    
    response = client.post('/users',
                          data=json.dumps(user_data),
                          content_type='application/json')
    assert response.status_code == 400
    
    data = json.loads(response.data)
    assert 'error' in data


@patch('app.get_db_connection')
def test_get_user_success(mock_db_conn, client):
    """Test getting a specific user successfully."""
    # Mock database connection and cursor
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
    mock_cursor.fetchone.return_value = {
        'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'created_at': '2023-01-01T00:00:00Z'
    }
    mock_db_conn.return_value = mock_conn
    
    response = client.get('/users/1')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['name'] == 'John Doe'
    assert data['email'] == 'john@example.com'


@patch('app.redis_client')
def test_get_user_from_cache(mock_redis, client):
    """Test getting a user from Redis cache."""
    cached_user = {
        'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'created_at': '2023-01-01T00:00:00Z'
    }
    mock_redis.get.return_value = json.dumps(cached_user)
    
    response = client.get('/users/1')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['name'] == 'John Doe'


def test_metrics_endpoint(client):
    """Test the metrics endpoint."""
    response = client.get('/metrics')
    assert response.status_code == 200
    
    # Check that it returns Prometheus format
    content = response.data.decode('utf-8')
    assert 'http_requests_total' in content
    assert 'http_request_duration_seconds' in content
    assert 'database_connections_active' in content
    assert 'redis_connections_active' in content


if __name__ == '__main__':
    pytest.main([__file__])
