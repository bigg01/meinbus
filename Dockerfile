# Use the official Python image from the Docker Hub as the base image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Make port 5000 available to the world outside this container
EXPOSE 5000

# Define environment variable
ENV FLASK_APP=meinbus.py

# Run the application with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "meinbus:app"]
#CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--log-level", "info", "--access-logfile", "-", "--error-logfile", "-", "meinbus:app"]