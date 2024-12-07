from pprint import pprint
from flask import Flask, render_template_string
from datetime import datetime, timezone
import requests
import os

app = Flask(__name__)

BASE_URL = "https://transport.opendata.ch/v1/"


# Custom filter to format datetime string to hh:mm:ss
@app.template_filter("format_time")
def format_time(value):
    if value is None:
        return "N/A"  # Return a default value or handle the error
    dt = datetime.strptime(value, "%Y-%m-%dT%H:%M:%S%z")
    return dt.strftime("%H:%M")


# Custom filter to calculate minutes until departure
@app.template_filter("minutes_until")
def minutes_until(value):
    if value is None:
        return "N/A"  # Return a default value or handle the error
    departure_time = datetime.strptime(value, "%Y-%m-%dT%H:%M:%S%z")
    now = datetime.now(timezone.utc)
    delta = departure_time - now
    total_seconds = int(delta.total_seconds() // 60)
    return total_seconds


@app.route("/")
def index():
    # stop_names = os.getenv("STOP_NAMES") or "Birchdörfli"
    #stop_names = ["Oberwiesenstrasse", "Birchdörfli"]
    stop_names = ["Oberwiesenstrasse"]

    station_coordinates = {
        "Oberwiesenstrasse": {"lat": 47.410473, "lon": 8.532815},
        "Birchdörfli": {"lat": 47.3780, "lon": 8.5400},
        "Brunnenhof": {"lat": 47.4000, "lon": 8.5500},
        "Bad Allenmoos": {"lat": 47.4100, "lon": 8.5600},
    }
    departures = {}
    for stop_name in stop_names:
        data = get_real_time_data(stop_name)
        if data:
            departures[stop_name] = data["stationboard"]
    disruptions = []  # get_disruptions()
    current_time = datetime.now().strftime("%H:%M:%S")
    connections = get_connection(from_station="Zürich, Oberwiesenstrasse", to_station="Zürich, Luchswiesen")

    html = """
    <html>
    <head>
        <title>Bus Station Abfahrten</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
        <meta http-equiv="refresh" content="30">
        <style>
            body {
                background-color: #000;
                color: #FFF;
                font-size: 28px;
            }

            .light-mode body {
                background-color: #FFF;
                color: #000;
            }

            .table td, .table th {
                color: #FFA500;
                border: 0;
                border-collapse: collapse;
            }

            .table {
                background-color: #000;
            }

            .light-mode .table {
                color: #FFF;
            }

            table {
                font-family: Arial, sans-serif;
                font-size: 30px;
                color: #333;
                background-color: black;
            }

            .light-mode table {
                background-color: white;
                color: #FFF;
            }

            th, td {
                padding: 0px;
                text-align: left;
                border: 0;
                border-collapse: collapse;
            }

        </style>
    </head>
    <body>
                    {% for stop_name, stop_departures in departures.items() %}
                        Abfahrt - {{ stop_name }} - {{ current_time }}           
                        <div class="table-container">
                            <table class="table is-fullwidth has-text-warning">
                                <thead class="has-background-black">
                                    <tr>
                                        <th>Linie</th>
                                        <th>Nach</th>
                                        <th>Abfahrt</th>
                                        <th>~</th>
                                        <th>in ca.</th>
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
                                    <td><span class="tag is-large is-{{ color }}">{{ line }}</td>
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


                {% endfor %}

                Verbindungen - Oberwiesenstrasse nach Luchswiesen
                    <div class="table-container">
                <table class="table is-fullwidth has-text-warning">
                    <thead class="has-background-black">
                        <tr>
                            <th>Linie</th>
                            <th>Abfahrt</th>
                            <th>Ankunft</th>
                            <th>Dauer</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for connection in connections['connections'] %}
                        <tr>
                            <td><i class='fa fa-bus'></i> {{ connection['sections'][0]['journey']['number'] }}</td>
                            <td>{{ connection['from']['departure'] | format_time }}</td>
                            <td>{{ connection['to']['arrival'] | format_time }}</td>
                            <td>{{ connection['duration'] }}</td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>

        <div class="tags has-addons">
        <span class="tag">Author</span>
        <span class="tag is-primary">Bigg01</span>
        </div>
    </body>
    </html>
    """
    return render_template_string(
        html,
        departures=departures,
        disruptions=disruptions,
        station_coordinates=station_coordinates,
        current_time=current_time,
        connections=connections,
    )


def get_real_time_data(stop_name):
    endpoint = f"{BASE_URL}locations"
    params = {"query": stop_name, "type": "station"}
    response = requests.get(endpoint, params=params)
    if response.status_code == 200:
        data = response.json()
        if data["stations"]:
            station_id = data["stations"][0]["id"]
            return get_departures(station_id)
        else:
            print("No station found")
            return None
    else:
        print(f"Error: {response.status_code}")
        return None


def get_departures(station_id):
    endpoint = f"{BASE_URL}stationboard"
    params = {"id": station_id, "limit": 5}
    response = requests.get(endpoint, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code}")
        return None


def get_disruptions():
    endpoint = f"{BASE_URL}disruptions"
    response = requests.get(endpoint)
    if response.status_code == 200:
        return response.json()["disruptions"]
    else:
        print(f"Error: {response.status_code}")
        return []


def get_connection(from_station, to_station):
    endpoint = f"{BASE_URL}connections"
    current_time = datetime.now().strftime("%H:%M")
    current_date = datetime.now().strftime("%Y-%m-%d")
    params = {
        "from": from_station,
        "to": to_station,
        "date": current_date,
        "time": current_time,
        "transportations": "bus",
        "limit": 3,
    }
    response = requests.get(endpoint, params=params)
    if response.status_code == 200:
        result = response.json()
        return result
    else:
        print(f"Error: {response.status_code}")
        return None


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
