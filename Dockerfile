FROM node:20-alpine AS frontend
WORKDIR /app
COPY landing/static/landing/lovable/package*.json ./
RUN npm ci
COPY landing/static/landing/lovable/ ./
RUN npm run build

FROM python:3.13-slim AS python-base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY . /app

FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=python-base /usr/local /usr/local
COPY --from=python-base /app /app

COPY --from=frontend /app/dist/assets /app/landing/static/landing/dist-assets/assets

ENV DJANGO_SETTINGS_MODULE=basejango.settings
RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "basejango.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "120"]
