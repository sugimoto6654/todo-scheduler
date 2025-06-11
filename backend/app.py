from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)                          # 開発中は全許可で簡単に

todos = []     # メモリ保持 (本番は DB)

@app.get("/api/todos")
def get_todos():
    return jsonify(todos)

@app.post("/api/todos")
def create_todo():
    data = request.get_json()
    todo = {"id": len(todos) + 1, "title": data["title"], "done": False}
    todos.append(todo)
    return jsonify(todo), 201

@app.put("/api/todos/<int:todo_id>")
def update_todo(todo_id):
    todo = next((t for t in todos if t["id"] == todo_id), None)
    if not todo:
        return {"error": "Not Found"}, 404
    todo.update(request.get_json())
    return jsonify(todo)

@app.delete("/api/todos/<int:todo_id>")
def delete_todo(todo_id):
    global todos
    todos = [t for t in todos if t["id"] != todo_id]
    return "", 204

if __name__ == "__main__":
    app.run(debug=True)
