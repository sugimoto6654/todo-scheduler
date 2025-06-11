# ---------- ビルドステージ ----------
FROM cirrusci/flutter:latest AS build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE=/api

# ---------- 配信ステージ ----------
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
# ルーティング対策：任意で 404 → index.html
RUN printf "server { \
    listen 80; \
    location / { try_files \$uri /index.html; } \
    location /api/ { proxy_pass http://backend:5000; } \
} " > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
    