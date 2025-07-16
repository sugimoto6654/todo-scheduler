#!/usr/bin/env python3
"""
データベースの作成とマイグレーション
"""

import sys
import os

# アプリケーションのパスを追加
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, db

def create_database():
    """データベースを作成"""
    with app.app_context():
        # 全てのテーブルを作成
        db.create_all()
        print("Database created successfully!")
        
        # テーブル情報を表示
        inspector = db.inspect(db.engine)
        tables = inspector.get_table_names()
        print(f"Tables created: {tables}")
        
        # Todoテーブルのカラム情報を表示
        if 'todos' in tables:
            columns = inspector.get_columns('todos')
            print("Todos table columns:")
            for col in columns:
                print(f"  - {col['name']}: {col['type']}")

if __name__ == "__main__":
    create_database()