class CustomReporter:
    """Custom Test Reporter"""
    SYMBOLS = {
        "passed": "✅",
        "failed": "❌",
        "skipped": "⏭️ ",
        "error": "⚠️ ",
    }
    
    @staticmethod
    def print_result(test_name: str, outcome: str, show_progress: bool = False, progress: str = ""):
        """Druckt einzelne Testergebnisse während der Ausführung"""
        symbol = "✅" if outcome == "passed" else "❌"
        
        if show_progress:
            print(f"{symbol} {test_name} [{progress}]")
        else:
            print(f"{symbol} {test_name}")
        
    @classmethod
    def print_category(cls, name, results):
        if not results:
            return
            
        print(f"\n{name}:")
        for test_name, status in results:
            symbol = cls.SYMBOLS.get(status, "  ")
            print(f"  {symbol} {test_name}")
            
    @classmethod
    def print_summary(cls, session):
        print("\n" + "="*80)
        print("📊 Test Results Summary")
        print("="*80)
        
        # Gruppiere Tests nach Kategorien
        basic = [(n, s) for n, s in session.results if "basic" in n.lower()]
        hardware = [(n, s) for n, s in session.results if "hardware" in n.lower()]
        profile = [(n, s) for n, s in session.results if "profile" in n.lower()]
        
        cls.print_category("📌 Basic Configuration Tests", basic)
        cls.print_category("🔧 Hardware Configuration Tests", hardware)
        cls.print_category("👤 Profile Configuration Tests", profile)
        
        passed, failed, skipped = session.statistics
        
        print("\n" + "-"*80)
        print("📈 Statistics:")
        print(f"  ✅ Passed:  {passed}")
        if failed: print(f"  ❌ Failed:  {failed}")
        if skipped: print(f"  ⏭️  Skipped: {skipped}")
        print(f"  ⏱️  Time:    {session.duration:.2f}s")
        print("="*80 + "\n")