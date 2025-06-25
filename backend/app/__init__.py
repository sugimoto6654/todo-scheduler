import os
from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy

# 環境変数をロード
load_dotenv()

db = SQLAlchemy()

# ---------- 1) まずアプリ本体を生成 ----------
app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///todos.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
CORS(app, resources={r"/*": {"origins": "*"}})

# ---------- 2) 拡張を初期化 ----------
db.init_app(app)

# ---------- 3) ここで routes / models を読み込む ----------
#    この時点では app・db が完全に出来ているので循環しない
from . import routes, models  # noqa: E402

# ---------- 4) テーブルを用意 ----------
with app.app_context():
    db.create_all()
