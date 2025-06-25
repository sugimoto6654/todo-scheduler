from datetime import date, datetime
from flask import request, jsonify
from . import app, db
from .models import Todo

# --------------------------------------
# ヘルパ関数
# --------------------------------------

def _parse_iso_date(value):
    """ISO‑8601 文字列を日付/日時型に変換する。
    対応できなければ None を返す。"""
    if not value:
        return None

    # "YYYY‑MM‑DD" → date
    try:
        return date.fromisoformat(value)
    except ValueError:
        pass

    # "YYYY‑MM‑DDThh:mm[:ss[.ffffff]][±hh:mm]" → datetime
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None

def _todo_to_dict(todo: Todo):
    """Todo モデルをフロント側へ返却する dict に変換する"""
    return {
        "id": todo.id,
        "title": todo.title,
        "date": todo.date.isoformat() if todo.date else None,
        "done": todo.done,
    }

# --------------------------------------
# ルーティング
# --------------------------------------

@app.route("/todos", methods=["GET"])
def list_todos():
    """Todo 一覧を id 昇順で返却"""
    todos = Todo.query.order_by(Todo.id).all()
    return jsonify([_todo_to_dict(t) for t in todos])


@app.route("/todos", methods=["POST"])
def create_todo():
    """新規 Todo を作成。title は必須。date は ISO‑8601 文字列で任意。
    指定が無い場合は今日の日付(Date 型)を自動採用。"""
    data = request.get_json(silent=True) or {}

    title = data.get("title", "").strip()
    if not title:
        return jsonify({"error": "title is required"}), 400

    # date を解釈（Date 型優先）。失敗時は今日。
    parsed_date = _parse_iso_date(data.get("date")) or date.today()

    todo = Todo(title=title, date=parsed_date, done=False)
    db.session.add(todo)
    db.session.commit()

    return jsonify(_todo_to_dict(todo)), 201


@app.route("/todos/<int:todo_id>", methods=["PATCH"])
def update_todo(todo_id):
    """title, done, date の部分更新をサポート"""
    todo = Todo.query.get_or_404(todo_id)
    data = request.get_json(silent=True) or {}

    if "title" in data:
        todo.title = data["title"].strip() or todo.title

    if "done" in data:
        todo.done = bool(data["done"])

    if "date" in data:
        new_date = _parse_iso_date(data["date"])
        if new_date:
            todo.date = new_date

    db.session.commit()
    # 204 だとフロント側が日付変更を即時表示できないので 200 で返す
    return jsonify(_todo_to_dict(todo))


@app.route("/todos/<int:todo_id>", methods=["DELETE"])
def delete_todo(todo_id):
    todo = Todo.query.get_or_404(todo_id)
    db.session.delete(todo)
    db.session.commit()
    return "", 204
