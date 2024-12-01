from flask import Flask, render_template_string
from datetime import datetime, timezone
import requests

app = Flask(__name__)

BASE_URL = 'https://transport.opendata.ch/v1/'

# Custom filter to format datetime string to hh:mm:ss
@app.template_filter("format_time")
def format_time(value):
    dt = datetime.strptime(value, "%Y-%m-%dT%H:%M:%S%z")
    return dt.strftime("%H:%M:%S")

# Custom filter to calculate minutes until departure
@app.template_filter("minutes_until")
def minutes_until(value):
    departure_time = datetime.strptime(value, "%Y-%m-%dT%H:%M:%S%z")
    now = datetime.now(timezone.utc)
    delta = departure_time - now
    total_seconds = int(delta.total_seconds() // 60)
    return total_seconds

@app.route("/")
def index():
    #stop_names = ["Oberwiesenstrasse", "Birchdörfli", "Brunnenhof", "Bad Allenmoos"]
    #stop_names = ["Birchdörfli", "Oberwiesenstrasse", "", "Brunnenhof", "Bad Allenmoos"]
    stop_names = ["Oberwiesenstrasse", "Birchdörfli"]
    station_coordinates = {
        "Oberwiesenstrasse": {"lat": 47.410473, "lon": 8.532815},
        "Birchdörfli": {"lat": 47.3780, "lon": 8.5400},
        "Brunnenhof": {"lat": 47.4000, "lon": 8.5500},
        "Bad Allenmoos": {"lat": 47.4100, "lon": 8.5600}
    }
    departures = {}
    for stop_name in stop_names:
        data = get_real_time_data(stop_name)
        if data:
            departures[stop_name] = data["stationboard"]
    disruptions = [] #get_disruptions()
    current_time = datetime.now().strftime("%H:%M:%S")
    
    html = """
    <html>
    <head>
        <title>Bus Station Departures</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.3/css/bulma.min.css">
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.7.1/dist/leaflet.css" />
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
        <meta http-equiv="refresh" content="30">
        <style>
            body {
                <!-- background-color: #1e1e1e; -->
                color: #f5aa63;
            }
            .container {
                margin-top: -20 px;
            }
            .card {
                background-color: #1e1e1e;
                color: #f5aa63;
            }
            .card-content {
                border-bottom: 1px solid #333;
            }
            #map {
                height: 400px;
                margin-top: 20px;
            }
            .small-text {
                font-size: 0.8em; /* Smaller font size for specific elements */
            }
        </style>
    </head>
    <body>

        <section class="section">
            <div class="container">
                 {% for stop_name, stop_departures in departures.items() %}
                <div class="panel">
                    <p class="panel-heading">
                        Abfahrt - {{ stop_name }} - {{ current_time }}
                    </p>
                    <div class="panel-block">
                        <div class="table-container">
                            <table class="table is-fullwidth is-striped is-hoverable small-text">
                                <thead>
                                    <tr>
                                        <th>Linie</th>
                                        <th>Nach</th>
                                        <th>Abfahrt</th>
                                        <th>Prognose</th>
                                        <th>bis Abfahrt</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {% for departure in stop_departures %}
                                    <tr>
                                {% set line = departure['number']| int %}
                                 {% if line == 11 %}
                                    {% set color = 'primary' %}
                                    {% elif line  == 62 %}
                                    {% set color = 'link' %}
                                    {% elif line  == 61 %}
                                    {% set color = 'info' %}
                                    {% elif line  == 32 %}
                                    {% set color = 'warning' %}
                                    {% else %}
                                    {% set color = 'white' %}
                                 {% endif %}
                                    <td><span class="tag is-{{ color }}">{{ line }}</td>
                                        <td>{{ departure['to'] }}</td>
                                        <td>{{ departure['stop']['departure'] | format_time }}</td>
                                        
                                        <td>{{ departure['stop']['prognosis']['departure'] | format_time }}</td>
                                        {% set minutes_until = departure['stop']['departure'] | minutes_until %}
                                        {% if minutes_until <= 0 %}
                                        <td> <i class='fa fa-bus'></i> </td>
                                        {% else %}
                                        <td>{{ minutes_until }}' </td>
                                        {% endif %}
                                        
                                    </tr>
                                    {% endfor %}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
                {% endfor %}
                <!-- Disruptions 
                <h2 class="title has-text-centered small-text">Disruptions</h2>
                <div class="table-container">
                    <table class="table is-fullwidth is-striped is-hoverable small-text">
                        <thead>
                            <tr>
                                <th>Title</th>
                                <th>Description</th>
                                <th>Category</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for disruption in disruptions %}
                            <tr>
                                <td>{{ disruption['title'] }}</td>
                                <td>{{ disruption['description'] }}</td>
                                <td>{{ disruption['category'] }}</td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
                -->
            </div>
        </section>
        <!-- Map 
        <script src="https://unpkg.com/leaflet@1.7.1/dist/leaflet.js"></script>
        <script>
            {% for stop_name, coords in station_coordinates.items() %}
            var map = L.map('map-{{ stop_name }}').setView([{{ coords.lat }}, {{ coords.lon }}], 13);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            }).addTo(map);
            L.marker([{{ coords.lat }}, {{ coords.lon }}]).addTo(map)
                .bindPopup('Station: {{ stop_name }}')
                .openPopup();
            {% endfor %}
        </script>
        -->
    </body>
    </html>
    """
    return render_template_string(html, departures=departures, disruptions=disruptions, station_coordinates=station_coordinates, current_time=current_time)

def get_real_time_data(stop_name):
    endpoint = f'{BASE_URL}locations'
    params = {
        'query': stop_name,
        'type': 'station'
    }
    response = requests.get(endpoint, params=params)
    if response.status_code == 200:
        data = response.json()
        if data['stations']:
            station_id = data['stations'][0]['id']
            return get_departures(station_id)
        else:
            print('No station found')
            return None
    else:
        print(f'Error: {response.status_code}')
        return None

def get_departures(station_id):
    endpoint = f'{BASE_URL}stationboard'
    params = {
        'id': station_id,
        'limit': 5
    }
    response = requests.get(endpoint, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        print(f'Error: {response.status_code}')
        return None

def get_disruptions():
    endpoint = f'{BASE_URL}disruptions'
    response = requests.get(endpoint)
    if response.status_code == 200:
        return response.json()['disruptions']
    else:
        print(f'Error: {response.status_code}')
        return []

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)