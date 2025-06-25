from datetime import date, datetime
import os
import requests
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
    指定が無い場合は None を保存。"""
    data = request.get_json(silent=True) or {}

    title = data.get("title", "").strip()
    if not title:
        return jsonify({"error": "title is required"}), 400

    # date を解釈（Date 型優先）。失敗時や未指定時は None。
    date_value = data.get("date")
    if date_value is not None and date_value != "":
        parsed_date = _parse_iso_date(date_value)
    else:
        parsed_date = None

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


@app.route("/chat", methods=["POST"])
def chat():
    """ChatGPT API を呼び出してレスポンスを返す"""
    try:
        data = request.get_json(silent=True) or {}
        print(f"Received data: {data}")  # デバッグログ
        
        messages = data.get("messages", [])
        if not messages:
            print("No messages provided")  # デバッグログ
            return jsonify({"error": "messages is required"}), 400
        
        # 環境変数からOpenAI設定を取得
        openai_key = os.getenv('OPENAI_API_KEY')
        openai_model = os.getenv('OPENAI_MODEL', 'gpt-3.5-turbo')
        mock_mode = os.getenv('CHAT_MOCK_MODE', 'false').lower() == 'true'
        
        print(f"OpenAI key configured: {bool(openai_key)}")  # デバッグログ
        print(f"OpenAI model: {openai_model}")  # デバッグログ
        print(f"Mock mode: {mock_mode}")  # デバッグログ
        
        # モックモードまたはAPIキーが設定されていない場合
        if mock_mode or not openai_key or openai_key == 'your_openai_api_key_here':
            print("Using mock response")  # デバッグログ
            # モックレスポンスを返す
            user_message = messages[-1]['content'] if messages else "Hello"
            mock_reply = f"これはモックレスポンスです。あなたのメッセージ「{user_message}」を受け取りました。実際のOpenAI APIを使用するには、backend/.envファイルでOPENAI_API_KEYを設定し、CHAT_MOCK_MODEをfalseにしてください。"
            return jsonify({"reply": mock_reply})
        
        print(f"Sending {len(messages)} messages to OpenAI")  # デバッグログ
        
        # OpenAI API を呼び出し
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {openai_key}',
            },
            json={
                'model': openai_model,
                'messages': messages,
                'temperature': 0.7,
            },
            timeout=30
        )
        
        print(f"OpenAI response status: {response.status_code}")  # デバッグログ
        
        if response.status_code == 200:
            data = response.json()
            reply = data['choices'][0]['message']['content']
            print(f"OpenAI reply received: {len(reply)} chars")  # デバッグログ
            return jsonify({"reply": reply.strip()})
        else:
            error_text = response.text
            print(f"OpenAI API error: {response.status_code} - {error_text}")  # デバッグログ
            return jsonify({"error": f"OpenAI API error {response.status_code}: {error_text}"}), 500
            
    except requests.exceptions.Timeout:
        print("OpenAI API timeout")  # デバッグログ
        return jsonify({"error": "OpenAI API timeout"}), 500
    except requests.exceptions.RequestException as e:
        print(f"Request error: {str(e)}")  # デバッグログ
        return jsonify({"error": f"Request error: {str(e)}"}), 500
    except Exception as e:
        print(f"Unexpected error: {str(e)}")  # デバッグログ
        import traceback
        traceback.print_exc()  # スタックトレースも出力
        return jsonify({"error": f"Unexpected error: {str(e)}"}), 500
