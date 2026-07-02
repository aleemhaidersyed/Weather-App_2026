import os
import sqlite3
import requests
from datetime import datetime, timedelta
from flask import Flask, request, jsonify

app = Flask(__name__)

# The database file name
DB_FILE = "weather.db"

# The API Key variable: falls back to "mock-key" if not set in the terminal
API_KEY = os.getenv("WEATHER_API_KEY", "mock-key") 

def init_db():
    """Guru Concept: Database Schema & Self-Healing
    This SQL script runs to ensure the database file and table exist.
    If the file is deleted, calling this function instantly recreates it.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS weather_cache (
            city TEXT PRIMARY KEY,
            temp REAL,
            description TEXT,
            humidity INTEGER,
            fetched_at TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

def get_cached_weather(city):
    """Query the SQL database for cached data"""
    init_db() # Self-healing check
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("SELECT temp, description, humidity, fetched_at FROM weather_cache WHERE city = ?", (city.lower(),))
    row = cursor.fetchone()
    conn.close()
    return row

def save_to_cache(city, temp, desc, humidity):
    """Insert or update weather records in SQL database"""
    init_db() # Self-healing check
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    now = datetime.now()
    cursor.execute('''
        INSERT OR REPLACE INTO weather_cache (city, temp, description, humidity, fetched_at)
        VALUES (?, ?, ?, ?, ?)
    ''', (city.lower(), temp, desc, humidity, now))
    conn.commit()
    conn.close()

@app.route('/api/weather', methods=['GET'])
def get_weather():
    city = request.args.get('city')
    if not city:
        return jsonify({"error": "City parameter is required"}), 400

    # 1. Check Cache
    cached = get_cached_weather(city)
    if cached:
        temp, desc, humidity, fetched_at = cached
        fetched_time = datetime.strptime(fetched_at, "%Y-%m-%d %H:%M:%S.%f")
        
        # 10 minutes cache validation policy
        if datetime.now() - fetched_time < timedelta(minutes=10):
            return jsonify({
                "source": "cache",
                "city": city.title(),
                "temp": temp,
                "description": desc,
                "humidity": humidity
            })

    # 2. Cache Miss: Fetch from API
    if API_KEY == "mock-key":
        # Offline Mock Fallback
        mock_data = {
            "temp": 22.5,
            "description": "mostly sunny",
            "humidity": 60
        }
        save_to_cache(city, mock_data["temp"], mock_data["description"], mock_data["humidity"])
        return jsonify({
            "source": "api_mocked",
            "city": city.title(),
            **mock_data
        })
    
    # Live External API Call
    try:
        url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&appid={API_KEY}&units=metric"
        r = requests.get(url)
        if r.status_code == 200:
            data = r.json()
            temp = data["main"]["temp"]
            desc = data["weather"][0]["description"]
            humidity = data["main"]["humidity"]
            save_to_cache(city, temp, desc, humidity)
            return jsonify({
                "source": "external_api",
                "city": city.title(),
                "temp": temp,
                "description": desc,
                "humidity": humidity
            })
        else:
            return jsonify({"error": "Failed to fetch weather data"}), r.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.after_request
def add_cors_headers(response):
    """Guru Concept: Enable CORS headers so the browser allows our 
    frontend webpage to request data from this API.
    """
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return response

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000)