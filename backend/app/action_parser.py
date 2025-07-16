import json
import re
from datetime import datetime, date
from typing import List, Dict, Any, Optional
from .models import Todo
from . import db

class ActionParser:
    """ChatGPTの応答を解析してタスク操作を実行するクラス"""
    
    def __init__(self):
        self.supported_actions = {
            'split_task': self._split_task,
            'adjust_deadline': self._adjust_deadline,
            'create_tasks': self._create_tasks,
            'update_tasks': self._update_tasks
        }
    
    def parse_and_execute(self, response_text: str) -> Dict[str, Any]:
        """
        ChatGPTの応答を解析してアクションを実行
        
        Args:
            response_text: ChatGPTからの応答テキスト
            
        Returns:
            実行結果の辞書
        """
        try:
            # JSON形式のアクションを抽出
            actions = self._extract_actions_from_text(response_text)
            
            if not actions:
                return {
                    'success': True,
                    'message': response_text,
                    'executed_actions': []
                }
            
            executed_actions = []
            
            for action in actions:
                result = self._execute_action(action)
                if result:
                    executed_actions.append(result)
            
            return {
                'success': True,
                'message': response_text,
                'executed_actions': executed_actions
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'message': response_text
            }
    
    def _extract_actions_from_text(self, text: str) -> List[Dict[str, Any]]:
        """テキストからJSON形式のアクションを抽出"""
        actions = []
        
        # JSONブロックを検索
        json_pattern = r'```json\s*(\{.*?\})\s*```'
        json_matches = re.findall(json_pattern, text, re.DOTALL)
        
        for match in json_matches:
            try:
                action_data = json.loads(match)
                if 'actions' in action_data:
                    actions.extend(action_data['actions'])
                elif 'type' in action_data:
                    actions.append(action_data)
            except json.JSONDecodeError:
                continue
        
        # マークダウンではないJSONも検索
        if not actions:
            json_pattern = r'\{[^{}]*"type"[^{}]*\}'
            json_matches = re.findall(json_pattern, text)
            
            for match in json_matches:
                try:
                    action_data = json.loads(match)
                    actions.append(action_data)
                except json.JSONDecodeError:
                    continue
        
        return actions
    
    def _execute_action(self, action: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """個別のアクションを実行"""
        action_type = action.get('type')
        
        if action_type not in self.supported_actions:
            return None
        
        try:
            return self.supported_actions[action_type](action)
        except Exception as e:
            return {
                'type': action_type,
                'success': False,
                'error': str(e)
            }
    
    def _split_task(self, action: Dict[str, Any]) -> Dict[str, Any]:
        """タスク分割を実行"""
        task_id = action.get('task_id')
        new_tasks = action.get('new_tasks', [])
        
        if not task_id or not new_tasks:
            raise ValueError("task_idとnew_tasksが必要です")
        
        # 元のタスクを取得
        original_task = Todo.query.get(task_id)
        if not original_task:
            raise ValueError(f"タスクID {task_id} が見つかりません")
        
        # 新しいサブタスクを作成
        created_tasks = []
        for i, task_data in enumerate(new_tasks):
            subtask_date = None
            if task_data.get('date'):
                subtask_date = self._parse_date(task_data['date'])
            
            subtask = Todo(
                title=task_data['title'],
                date=subtask_date,
                parent_id=original_task.id,
                priority=task_data.get('priority', i),
                done=False
            )
            db.session.add(subtask)
            created_tasks.append({
                'title': subtask.title,
                'date': subtask.date.isoformat() if subtask.date else None,
                'priority': subtask.priority
            })
        
        # 元のタスクを完了扱いにする（サブタスクが作成されたため）
        original_task.done = True
        
        db.session.commit()
        
        return {
            'type': 'split_task',
            'success': True,
            'original_task_id': task_id,
            'created_tasks': created_tasks,
            'message': f"タスク「{original_task.title}」を{len(created_tasks)}個のサブタスクに分割しました"
        }
    
    def _adjust_deadline(self, action: Dict[str, Any]) -> Dict[str, Any]:
        """期限調整を実行"""
        updates = action.get('updates', [])
        
        if not updates:
            raise ValueError("updatesが必要です")
        
        updated_tasks = []
        
        for update in updates:
            task_id = update.get('task_id')
            new_date = update.get('new_date')
            
            if not task_id:
                continue
            
            task = Todo.query.get(task_id)
            if not task:
                continue
            
            old_date = task.date.isoformat() if task.date else None
            
            if new_date:
                task.date = self._parse_date(new_date)
            else:
                task.date = None
            
            updated_tasks.append({
                'task_id': task_id,
                'title': task.title,
                'old_date': old_date,
                'new_date': task.date.isoformat() if task.date else None
            })
        
        db.session.commit()
        
        return {
            'type': 'adjust_deadline',
            'success': True,
            'updated_tasks': updated_tasks,
            'message': f"{len(updated_tasks)}個のタスクの期限を調整しました"
        }
    
    def _create_tasks(self, action: Dict[str, Any]) -> Dict[str, Any]:
        """新しいタスクを作成"""
        tasks = action.get('tasks', [])
        
        if not tasks:
            raise ValueError("tasksが必要です")
        
        created_tasks = []
        
        for task_data in tasks:
            task_date = None
            if task_data.get('date'):
                task_date = self._parse_date(task_data['date'])
            
            task = Todo(
                title=task_data['title'],
                date=task_date,
                priority=task_data.get('priority', 0),
                done=False
            )
            db.session.add(task)
            created_tasks.append({
                'title': task.title,
                'date': task.date.isoformat() if task.date else None,
                'priority': task.priority
            })
        
        db.session.commit()
        
        return {
            'type': 'create_tasks',
            'success': True,
            'created_tasks': created_tasks,
            'message': f"{len(created_tasks)}個の新しいタスクを作成しました"
        }
    
    def _update_tasks(self, action: Dict[str, Any]) -> Dict[str, Any]:
        """既存タスクを更新"""
        updates = action.get('updates', [])
        
        if not updates:
            raise ValueError("updatesが必要です")
        
        updated_tasks = []
        
        for update in updates:
            task_id = update.get('task_id')
            if not task_id:
                continue
            
            task = Todo.query.get(task_id)
            if not task:
                continue
            
            # タイトル更新
            if 'title' in update:
                task.title = update['title']
            
            # 日付更新
            if 'date' in update:
                if update['date']:
                    task.date = self._parse_date(update['date'])
                else:
                    task.date = None
            
            # 完了状態更新
            if 'done' in update:
                task.done = update['done']
            
            # 優先度更新
            if 'priority' in update:
                task.priority = update['priority']
            
            updated_tasks.append({
                'task_id': task_id,
                'title': task.title,
                'date': task.date.isoformat() if task.date else None,
                'done': task.done,
                'priority': task.priority
            })
        
        db.session.commit()
        
        return {
            'type': 'update_tasks',
            'success': True,
            'updated_tasks': updated_tasks,
            'message': f"{len(updated_tasks)}個のタスクを更新しました"
        }
    
    def _parse_date(self, date_str: str) -> date:
        """日付文字列を解析"""
        if not date_str:
            return None
        
        # ISO形式
        try:
            return date.fromisoformat(date_str)
        except ValueError:
            pass
        
        # 日本語形式（例：2025年1月20日）
        japanese_date_pattern = r'(\d{4})年(\d{1,2})月(\d{1,2})日'
        match = re.match(japanese_date_pattern, date_str)
        if match:
            year, month, day = match.groups()
            return date(int(year), int(month), int(day))
        
        # その他の形式（例：2025-01-20）
        try:
            return datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            pass
        
        raise ValueError(f"日付形式が不正です: {date_str}")