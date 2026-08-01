# CodexaCoin block explorer backend image. Stateless -- no volume needed
# (unlike vps-gateway's, which persists a SQLite user/deposit database).

FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash cac-explorer

WORKDIR /app
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app/

USER cac-explorer
EXPOSE 8081

ENTRYPOINT ["gunicorn", "--workers", "4", "--bind", "0.0.0.0:8081", "--access-logfile", "-", "app:app"]
