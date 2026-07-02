// 1. Select DOM elements to read and update
const cityInput = document.getElementById('city-input');
const searchBtn = document.getElementById('search-btn');
const weatherCard = document.getElementById('weather-card');
const errorCard = document.getElementById('error-card');

const weatherCity = document.getElementById('weather-city');
const weatherTemp = document.getElementById('weather-temp');
const weatherDesc = document.getElementById('weather-desc');
const weatherHumidity = document.getElementById('weather-humidity');
const weatherSource = document.getElementById('weather-source');
const errorMsg = document.getElementById('error-msg');

// 2. Define the Local Flask API Endpoint URL
const API_URL = "http://localhost:5000/api/weather";

async function fetchWeather() {
  const city = cityInput.value.trim();
  
  if (!city) {
    showError("Please enter a city name.");
    return;
  }

  try {
    // Clear any previous error states
    errorCard.style.display = 'none';
    
    // Fetch data asynchronously from our Flask API
    const response = await fetch(`${API_URL}?city=${encodeURIComponent(city)}`);
    const data = await response.json();

    if (response.ok) {
      // SUCCESS: Populate the weather card details
      weatherCity.textContent = data.city;
      weatherTemp.textContent = data.temp.toFixed(1);
      weatherDesc.textContent = data.description;
      weatherHumidity.textContent = `${data.humidity}%`;
      
      // Dynamic Source Badge styling based on cache status
      weatherSource.textContent = data.source;
      if (data.source === 'cache') {
        weatherSource.style.backgroundColor = '#10b981'; // Glistening green for database Cache Hit
      } else {
        weatherSource.style.backgroundColor = '#0369a1'; // Sky blue for API Fetch / Cache Miss
      }

      // Display the weather card
      weatherCard.style.display = 'block';
    } else {
      // Backend error returned (e.g. invalid city or API limits)
      showError(data.error || "Failed to retrieve weather data.");
    }
  } catch (error) {
    // Network/Connection error (e.g. Flask backend is offline)
    showError("Cannot connect to backend server. Make sure your Flask app.py is running on port 5000.");
  }
}

function showError(message) {
  weatherCard.style.display = 'none';
  errorMsg.textContent = message;
  errorCard.style.display = 'block';
}

// 3. Bind events to trigger our search
searchBtn.addEventListener('click', fetchWeather);

cityInput.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') {
    fetchWeather();
  }
});