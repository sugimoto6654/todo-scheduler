from . import db

class Todo(db.Model):
    __tablename__ = "todos"
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(120), nullable=False)
    date = db.Column(db.Date, nullable=True)
    done = db.Column(db.Boolean, default=False)
    parent_id = db.Column(db.Integer, db.ForeignKey('todos.id'), nullable=True)
    priority = db.Column(db.Integer, default=0)

    # リレーションシップ
    parent = db.relationship('Todo', remote_side=[id], backref='children')

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "date": self.date.isoformat() if self.date else None,
            "done": self.done,
            "parent_id": self.parent_id,
            "priority": self.priority,
        }

    def split_into_tasks(self, new_tasks_data):
        """
        このタスクを複数のサブタスクに分割
        new_tasks_data: [{"title": "...", "date": "...", "priority": ...}, ...]
        """
        subtasks = []
        for task_data in new_tasks_data:
            subtask = Todo(
                title=task_data['title'],
                date=task_data.get('date'),
                parent_id=self.id,
                priority=task_data.get('priority', 0),
                done=False
            )
            subtasks.append(subtask)
        return subtasks

    def get_subtasks(self):
        """このタスクのサブタスクを取得"""
        return Todo.query.filter_by(parent_id=self.id).order_by(Todo.priority.desc()).all()

    def is_parent_task(self):
        """このタスクがサブタスクを持つかどうか"""
        return len(self.children) > 0

    def get_completion_rate(self):
        """サブタスクの完了率を計算"""
        if not self.is_parent_task():
            return 1.0 if self.done else 0.0
        
        subtasks = self.get_subtasks()
        if not subtasks:
            return 1.0 if self.done else 0.0
        
        completed = sum(1 for task in subtasks if task.done)
        return completed / len(subtasks)