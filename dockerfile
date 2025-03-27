# Use a lightweight official Python image
FROM python:3.8-slim
# Install git and any build tools if needed
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
# Clone the repository
RUN git clone https://github.com/gurkanakdeniz/example-flask-crud.git
# Set the working directory
WORKDIR /example-flask-crud
# Upgrade pip and install required packages
RUN pip install --upgrade pip && \
    pip install -r requirements.txt
# Set the Flask application environment variable
ENV FLASK_APP=crudapp.py
# Expose port 80
EXPOSE 80
# Initialize the database, run migrations, and start the app
RUN flask db init && \
    flask db migrate -m "entries table" && \
    flask db upgrade
# Start Flask; bind to all interfaces so it’s accessible externally
CMD ["flask", "run", "--host=0.0.0.0", "--port=80"]