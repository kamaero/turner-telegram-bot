FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 botuser

WORKDIR /app

COPY requirements.txt .
COPY schema.sql .

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install cryptography pymysql

COPY . .

RUN touch .env php_config.php

RUN chown -R botuser:botuser /app

USER botuser

COPY --chown=botuser:botuser docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["python", "bot.py"]
