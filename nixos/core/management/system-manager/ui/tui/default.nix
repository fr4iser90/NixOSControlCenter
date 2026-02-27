# System Manager TUI - Example implementation using tui-engine
{ lib, pkgs, getModuleApi }:

let
  tuiEngine = getModuleApi "tui-engine";

  # Simple system info display TUI
  systemManagerGoCode = ''
    package main

    import (
        "fmt"
        "log"
        "os/exec"
        "strings"
        tea "github.com/charmbracelet/bubbletea"
    )

    type model struct {
        systemInfo string
        loading     bool
    }

    func (m model) Init() tea.Cmd {
        return getSystemInfo
    }

    func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
        switch msg := msg.(type) {
        case tea.KeyMsg:
            switch msg.String() {
            case "q", "ctrl+c":
                return m, tea.Quit
            case "r":
                m.loading = true
                return m, getSystemInfo
            }
        case systemInfoMsg:
            m.systemInfo = string(msg)
            m.loading = false
            return m, nil
        }
        return m, nil
    }

    func (m model) View() string {
        if m.loading {
            return "🔄 Loading system information..."
        }

        return fmt.Sprintf(`🔧 System Manager TUI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

%s

Shortcuts:
• q: Quit
• r: Refresh

Status: ✅ TUI Engine Working!
`, m.systemInfo)
    }

    type systemInfoMsg string

    func getSystemInfo() tea.Cmd {
        return tea.Cmd(func() tea.Msg {
            cmd := exec.Command("uname", "-a")
            output, err := cmd.Output()
            if err != nil {
                return systemInfoMsg("Error getting system info")
            }
            return systemInfoMsg(output)
        })
    }

    func main() {
        // log.Println("🚀 System Manager TUI starting...")
        // log.Println("✅ TUI Engine integration successful!")

        p := tea.NewProgram(model{loading: true})
        if _, err := p.Run(); err != nil {
            fmt.Printf("Error: %v", err)
            os.Exit(1)
        }
    }
  '';

in
  tuiEngine.buildTUI {
    name = "system-manager";
    goCode = systemManagerGoCode;
    discoveryScript = ""; # Not needed for this simple example
    inherit pkgs;
  }
