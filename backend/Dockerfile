FROM python:3.11-slim
WORKDIR /app
# 依存インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# アプリ本体
COPY . .
# Gunicorn で本番起動
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
