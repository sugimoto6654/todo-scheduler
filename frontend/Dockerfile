FROM dart:3.4-sdk AS build
SHELL ["/bin/bash", "-c"]

ARG FLUTTER_VERSION=3.22.2

# ❶ FVM のキャッシュ先を pub-cache から分離
ENV FVM_CACHE_PATH="/root/fvm"
# ❷ fvm & flutter の実行パス
ENV PATH="$PATH:/root/.pub-cache/bin:/root/fvm/default/bin"

RUN apt-get update && apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev git curl unzip xz-utils zip
RUN dart pub global activate fvm
# Flutter を cache-dir に clone（pub get は後でまとめて実行）
RUN fvm install "${FLUTTER_VERSION}"
RUN fvm global  "${FLUTTER_VERSION}"
# PATH が正しく通っているか確認
RUN flutter --version

WORKDIR /app
COPY pubspec.yaml .
RUN flutter pub get
COPY . .
RUN flutter config --enable-web
RUN flutter build web --release -t lib/main.dart --dart-define=API=http://localhost:5001 --dart-define=DEBUG_MODE=false

FROM nginx:alpine AS runtime
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
