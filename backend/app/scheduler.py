import os
from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.executors.pool import ThreadPoolExecutor
import atexit
from .line_service import LineNotificationService


class NotificationScheduler:
    """タスク通知のスケジューラー"""
    
    def __init__(self):
        """スケジューラーを初期化"""
        self.scheduler = None
        self.line_service = LineNotificationService()
        self.enabled = os.getenv('NOTIFICATION_SCHEDULER_ENABLED', 'true').lower() == 'true'
        
        if self.enabled:
            # BackgroundSchedulerを設定
            executors = {
                'default': ThreadPoolExecutor(20),
            }
            
            job_defaults = {
                'coalesce': False,
                'max_instances': 3
            }
            
            self.scheduler = BackgroundScheduler(
                executors=executors,
                job_defaults=job_defaults,
                timezone='Asia/Tokyo'  # 日本時間
            )
            
            print("Notification scheduler initialized.")
        else:
            print("Notification scheduler is disabled.")
    
    def start(self):
        """スケジューラーを開始"""
        if not self.enabled or not self.scheduler:
            print("Scheduler is disabled or not initialized.")
            return
        
        try:
            # 毎朝8:00に日次通知を送信するジョブを追加
            self.scheduler.add_job(
                func=self._send_daily_notification,
                trigger=CronTrigger(hour=8, minute=0),
                id='daily_notification',
                name='Daily Task Notification',
                replace_existing=True
            )
            
            # スケジューラーを開始
            self.scheduler.start()
            print("Notification scheduler started. Daily notifications at 8:00 AM JST.")
            
            # アプリケーション終了時にスケジューラーを停止
            atexit.register(self.shutdown)
            
        except Exception as e:
            print(f"Error starting scheduler: {e}")
    
    def shutdown(self):
        """スケジューラーを停止"""
        if self.scheduler and self.scheduler.running:
            self.scheduler.shutdown()
            print("Notification scheduler shutdown.")
    
    def _send_daily_notification(self):
        """日次通知を送信（内部メソッド）"""
        try:
            print(f"Sending daily notification at {datetime.now()}")
            result = self.line_service.send_daily_task_notification()
            
            if result:
                print("Daily notification sent successfully.")
            else:
                print("Failed to send daily notification.")
                
        except Exception as e:
            print(f"Error in daily notification job: {e}")
    
    def send_test_notification(self):
        """テスト通知を送信（デバッグ用）"""
        try:
            print(f"Sending test notification at {datetime.now()}")
            
            # テスト用のカスタムメッセージ
            test_message = (
                "🧪 テスト通知です\n"
                f"📅 {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}\n"
                "\n"
                "この通知が届いていれば、LINE Bot の設定は正常に動作しています！"
            )
            
            result = self.line_service.send_custom_notification(test_message)
            
            if result:
                print("Test notification sent successfully.")
                return True
            else:
                print("Failed to send test notification.")
                return False
                
        except Exception as e:
            print(f"Error in test notification: {e}")
            return False
    
    def get_jobs(self):
        """登録されているジョブの一覧を取得"""
        if not self.scheduler:
            return []
        
        jobs = []
        for job in self.scheduler.get_jobs():
            jobs.append({
                'id': job.id,
                'name': job.name,
                'next_run_time': job.next_run_time.isoformat() if job.next_run_time else None,
                'trigger': str(job.trigger)
            })
        
        return jobs
    
    def get_status(self):
        """スケジューラーの状態を取得"""
        return {
            'enabled': self.enabled,
            'running': self.scheduler.running if self.scheduler else False,
            'jobs_count': len(self.scheduler.get_jobs()) if self.scheduler else 0,
            'line_service_status': self.line_service.get_status()
        }