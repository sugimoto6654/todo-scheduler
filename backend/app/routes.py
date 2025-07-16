from datetime import date, datetime
import os
import requests
from flask import request, jsonify
from . import app, db
from .models import Todo
from .action_parser import ActionParser

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


@app.route("/todos/bulk", methods=["POST"])
def bulk_create_todos():
    """複数のTodoを一括作成"""
    data = request.get_json(silent=True) or {}
    todos_data = data.get("todos", [])
    
    if not todos_data:
        return jsonify({"error": "todos is required"}), 400
    
    created_todos = []
    
    for todo_data in todos_data:
        title = todo_data.get("title", "").strip()
        if not title:
            continue
        
        # 日付を解析
        date_value = todo_data.get("date")
        if date_value:
            parsed_date = _parse_iso_date(date_value)
        else:
            parsed_date = None
        
        todo = Todo(
            title=title,
            date=parsed_date,
            done=todo_data.get("done", False),
            parent_id=todo_data.get("parent_id"),
            priority=todo_data.get("priority", 0)
        )
        db.session.add(todo)
        created_todos.append(todo)
    
    db.session.commit()
    
    return jsonify([_todo_to_dict(todo) for todo in created_todos]), 201


@app.route("/todos/bulk", methods=["PATCH"])
def bulk_update_todos():
    """複数のTodoを一括更新"""
    data = request.get_json(silent=True) or {}
    updates = data.get("updates", [])
    
    if not updates:
        return jsonify({"error": "updates is required"}), 400
    
    updated_todos = []
    
    for update in updates:
        todo_id = update.get("id")
        if not todo_id:
            continue
        
        todo = Todo.query.get(todo_id)
        if not todo:
            continue
        
        # フィールドを更新
        if "title" in update:
            todo.title = update["title"].strip() or todo.title
        if "done" in update:
            todo.done = bool(update["done"])
        if "date" in update:
            todo.date = _parse_iso_date(update["date"])
        if "priority" in update:
            todo.priority = update["priority"]
        
        updated_todos.append(todo)
    
    db.session.commit()
    
    return jsonify([_todo_to_dict(todo) for todo in updated_todos])


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
        
        # 現在月のタスク情報を取得してsystemプロンプトに追加
        current_month_tasks = data.get("current_month_tasks", "")
        if current_month_tasks:
            system_prompt = {
                "role": "system",
                "content": f"""あなたはタスク管理アシスタントです。現在、ユーザーは以下のタスクを管理しています：

{current_month_tasks}

上記のタスク情報を参考にして、ユーザーのリクエストに応じてタスクの分割、統合、優先度の提案、スケジュール調整などを行ってください。タスクIDを参照する際は、上記リストの情報を使用してください。

## 重要：アクション実行について

タスクの分割や期限調整などの実際の操作を行う場合は、以下の形式でJSON形式のアクションを応答に含めてください：

### タスク分割の場合：
```json
{{
  "type": "split_task",
  "task_id": 123,
  "new_tasks": [
    {{"title": "サブタスク1", "date": "2025-01-20", "priority": 1}},
    {{"title": "サブタスク2", "date": "2025-01-22", "priority": 2}}
  ]
}}
```

### 期限調整の場合：
```json
{{
  "type": "adjust_deadline",
  "updates": [
    {{"task_id": 123, "new_date": "2025-01-25"}},
    {{"task_id": 124, "new_date": "2025-01-26"}}
  ]
}}
```

このJSONアクションが応答に含まれている場合、システムが自動的にデータベースに反映します。
通常の会話や提案の場合はJSONアクションを含める必要はありません。"""
            }
            # systemプロンプトをmessagesの先頭に挿入
            messages = [system_prompt] + messages
            print(f"Added system prompt with {len(current_month_tasks)} chars of task context")  # デバッグログ
        
        # 環境変数からOpenAI設定を取得
        openai_key = os.getenv('OPENAI_API_KEY')
        openai_model = os.getenv('OPENAI_MODEL', 'gpt-4o-2024-08-06')
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
            
            # アクション解析と実行
            action_parser = ActionParser()
            action_result = action_parser.parse_and_execute(reply)
            
            if action_result['success']:
                response_data = {
                    "reply": action_result['message'],
                    "actions_executed": action_result.get('executed_actions', [])
                }
                return jsonify(response_data)
            else:
                return jsonify({
                    "reply": reply.strip(),
                    "action_error": action_result.get('error')
                })
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
