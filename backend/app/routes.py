from flask import request, jsonify
from . import app, db
from .models import Todo

@app.route("/todos", methods=["GET"])
def list_todos():
    todos = Todo.query.order_by(Todo.id).all()
    return jsonify([{"id": t.id, "title": t.title, "done": t.done} for t in todos])

@app.route("/todos", methods=["POST"])
def create_todo():
    data = request.get_json()
    todo = Todo(title=data.get("title", ""), done=False)
    db.session.add(todo)
    db.session.commit()
    return jsonify({"id": todo.id}), 201

@app.route("/todos/<int:todo_id>", methods=["PATCH"])
def update_todo(todo_id):
    todo = Todo.query.get_or_404(todo_id)
    data = request.get_json()
    todo.title = data.get("title", todo.title)
    todo.done = data.get("done", todo.done)
    db.session.commit()
    return "", 204

@app.route("/todos/<int:todo_id>", methods=["DELETE"])
def delete_todo(todo_id):
    todo = Todo.query.get_or_404(todo_id)
    db.session.delete(todo)
    db.session.commit()
    return "", 204
