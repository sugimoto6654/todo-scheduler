import os
from datetime import datetime, date
import pytz
from linebot import LineBotApi
from linebot.models import TextSendMessage
from linebot.exceptions import LineBotApiError
from .models import Todo


class LineNotificationService:
    """LINE Bot を使用した通知サービス"""
    
    def __init__(self):
        """LINE Bot API クライアントを初期化"""
        self.channel_access_token = os.getenv('LINE_CHANNEL_ACCESS_TOKEN')
        self.user_id = os.getenv('LINE_USER_ID')
        
        if self.channel_access_token and self.channel_access_token != 'your_line_channel_access_token_here':
            self.line_bot_api = LineBotApi(self.channel_access_token)
            self.enabled = True
        else:
            self.line_bot_api = None
            self.enabled = False
            print("LINE Bot is disabled. Set LINE_CHANNEL_ACCESS_TOKEN to enable notifications.")
    
    def send_daily_task_notification(self):
        """今日のタスク一覧をLINEに送信"""
        if not self.enabled or not self.user_id:
            print("LINE notification is disabled or USER_ID is not set.")
            return False
        
        try:
            # 今日の日付を取得
            today = date.today()
            
            # 今日のタスクを取得（完了していないもの）
            today_tasks = Todo.query.filter(
                Todo.date == today,
                Todo.done == False
            ).order_by(Todo.priority.desc()).all()
            
            # 期限なしのタスクも取得（完了していないもの）
            no_deadline_tasks = Todo.query.filter(
                Todo.date == None,
                Todo.done == False
            ).order_by(Todo.priority.desc()).limit(5).all()
            
            # メッセージを構築
            message = self._build_daily_message(today, today_tasks, no_deadline_tasks)
            
            # LINE メッセージを送信
            self.line_bot_api.push_message(
                self.user_id,
                TextSendMessage(text=message)
            )
            
            print(f"Daily notification sent successfully to {self.user_id}")
            return True
            
        except LineBotApiError as e:
            print(f"LINE Bot API Error: {e}")
            return False
        except Exception as e:
            print(f"Error sending daily notification: {e}")
            return False
    
    def send_custom_notification(self, message):
        """カスタムメッセージをLINEに送信（デバッグ用）"""
        if not self.enabled or not self.user_id:
            print("LINE notification is disabled or USER_ID is not set.")
            return False
        
        try:
            self.line_bot_api.push_message(
                self.user_id,
                TextSendMessage(text=message)
            )
            print(f"Custom notification sent successfully to {self.user_id}")
            return True
            
        except LineBotApiError as e:
            print(f"LINE Bot API Error: {e}")
            return False
        except Exception as e:
            print(f"Error sending custom notification: {e}")
            return False
    
    def _build_daily_message(self, today, today_tasks, no_deadline_tasks):
        """日次通知メッセージを構築"""
        # 日付をJSTで表示
        jst = pytz.timezone('Asia/Tokyo')
        today_jst = datetime.now(jst).date()
        
        # ヘッダー
        message_lines = [
            "🌅 おはようございます！",
            f"📅 {today_jst.strftime('%Y年%m月%d日')} のタスクをお知らせします。"
        ]
        
        # 今日のタスク
        if today_tasks:
            message_lines.append("\n📋 今日のタスク:")
            for i, task in enumerate(today_tasks, 1):
                priority_icon = "🔥" if task.priority >= 3 else "⭐" if task.priority >= 1 else "📌"
                message_lines.append(f"{i}. {priority_icon} {task.title}")
        else:
            message_lines.append("\n✅ 今日は予定されたタスクがありません！")
        
        # 期限なしのタスク（参考）
        if no_deadline_tasks:
            message_lines.append("\n💡 期限なしタスク（参考）:")
            for i, task in enumerate(no_deadline_tasks[:3], 1):  # 最大3つまで表示
                priority_icon = "🔥" if task.priority >= 3 else "⭐" if task.priority >= 1 else "📌"
                message_lines.append(f"• {priority_icon} {task.title}")
            if len(no_deadline_tasks) > 3:
                message_lines.append(f"...他{len(no_deadline_tasks) - 3}件")
        
        # フッター
        message_lines.extend([
            "",
            "💪 今日も頑張りましょう！"
        ])
        
        return "\n".join(message_lines)
    
    def get_status(self):
        """サービスの状態を取得"""
        return {
            "enabled": self.enabled,
            "has_access_token": bool(self.channel_access_token and self.channel_access_token != 'your_line_channel_access_token_here'),
            "has_user_id": bool(self.user_id and self.user_id != 'your_line_user_id_here'),
            "user_id": self.user_id if self.user_id and self.user_id != 'your_line_user_id_here' else None
        }