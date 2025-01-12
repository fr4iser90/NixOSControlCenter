import time

class SessionManager:
    """Globaler Testsession-Manager"""
    def __init__(self):
        self.start_time = None
        self.results = []
        
    def start(self):
        self.start_time = time.time()
        self.results = []
        
    def add_result(self, name, status):
        self.results.append((name, status))
        
    @property
    def duration(self):
        return time.time() - self.start_time
        
    @property
    def statistics(self):
        passed = sum(1 for _, status in self.results if status == "passed")
        failed = sum(1 for _, status in self.results if status == "failed")
        skipped = sum(1 for _, status in self.results if status == "skipped")
        return passed, failed, skipped