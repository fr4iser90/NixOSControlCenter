## Path: src/backend/services/system_monitor.py

import psutil  # Python package for system and process monitoring
import threading
import time

class SystemMonitor:
    def __init__(self):
        self.monitoring = False
        self.monitor_thread = None

    def get_cpu_usage(self):
        return psutil.cpu_percent(interval=1)  # Get CPU usage in percentage

    def get_memory_usage(self):
        memory = psutil.virtual_memory()
        return memory.percent  # Get memory usage in percentage

    def get_disk_usage(self):
        disk = psutil.disk_usage('/')
        total_disk = disk.total / (1024 * 1024 * 1024)  # Convert bytes to GB
        used_disk = disk.used / (1024 * 1024 * 1024)    # Convert bytes to GB
        free_disk = disk.free / (1024 * 1024 * 1024)    # Convert bytes to GB
        return total_disk, used_disk, free_disk  # Return the disk usage in GB

    def get_network_activity(self):
        net = psutil.net_io_counters()
        return net.bytes_sent, net.bytes_recv  # Network bytes sent and received

    def get_system_metrics(self):
        total_disk, used_disk, free_disk = self.get_disk_usage()
        return {
            "cpu": self.get_cpu_usage(),
            "memory": self.get_memory_usage(),
            "disk": self.get_disk_usage()[0],  # Total disk percentage
            "disk_used": used_disk,
            "disk_free": free_disk,
            "network": self.get_network_activity()
        }

    def start_monitoring(self, callback, interval=1):
        """Start monitoring system metrics."""
        if not self.monitoring:
            self.monitoring = True
            self.monitor_thread = threading.Thread(target=self._monitor, args=(callback, interval))
            self.monitor_thread.daemon = True
            self.monitor_thread.start()

    def stop_monitoring(self):
        """Stop monitoring system metrics."""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join()
            self.monitor_thread = None  # Reset the thread to allow restarting

    def _monitor(self, callback, interval):
        """Internal method to monitor system metrics."""
        while self.monitoring:
            metrics = self.get_system_metrics()
            callback(metrics)  # Call the callback with the latest metrics
            time.sleep(interval)

