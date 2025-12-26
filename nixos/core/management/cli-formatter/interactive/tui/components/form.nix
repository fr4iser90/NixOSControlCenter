{ lib, bubbletea-src ? "github.com/charmbracelet/bubbletea" }:

let
  formCode = ''
    package components

    import (
    	tea "${bubbletea-src}"
    	"github.com/charmbracelet/lipgloss"
    	"strings"
    	"fmt"
    )

    // FormField represents a form input field
    type FormField struct {
    	ID          string
    	Label       string
    	Type        string
    	Value       string
    	Placeholder string
    	Required    bool
    	Validation  func(string) error
    	Options     []string
    }

    // FormTemplate handles form input
    type FormTemplate struct {
    	fields      []FormField
    	focus       int
    	submitting  bool
    	error       error
    	title       string
    	onSubmit    func(map[string]string) tea.Cmd
    	onCancel    func() tea.Cmd
    }

    func NewFormTemplate(config map[string]interface{}) *FormTemplate {
    	ft := &FormTemplate{}

    	// Load config
    	if title, ok := config["title"].(string); ok {
    		ft.title = title
    	} else {
    		ft.title = "Form"
    	}

    	// Load fields
    	if fields, ok := config["fields"]; ok {
    		if fieldSlice, ok := fields.([]interface{}); ok {
    			ft.fields = make([]FormField, len(fieldSlice))
    			for i, field := range fieldSlice {
    				if fieldMap, ok := field.(map[string]interface{}); ok {
    					ft.fields[i] = FormField{
    						ID:          getStringValue(fieldMap, "id", ""),
    						Label:       getStringValue(fieldMap, "label", ""),
    						Type:        getStringValue(fieldMap, "type", "text"),
    						Value:       getStringValue(fieldMap, "value", ""),
    						Placeholder: getStringValue(fieldMap, "placeholder", ""),
    						Required:    getBoolValue(fieldMap, "required", false),
    					}

    					// Load options for select fields
    					if options, ok := fieldMap["options"]; ok {
    						if optSlice, ok := options.([]interface{}); ok {
    							ft.fields[i].Options = make([]string, len(optSlice))
    							for j, opt := range optSlice {
    								ft.fields[i].Options[j] = fmt.Sprintf("%v", opt)
    							}
    						}
    					}
    				}
    			}
    		}
    	}

    	return ft
    }

    func (ft *FormTemplate) Init() tea.Cmd {
    	return nil
    }

    func (ft *FormTemplate) Update(msg tea.Msg) (interface{}, tea.Cmd) {
    	switch msg := msg.(type) {
    	case tea.KeyMsg:
    		switch msg.String() {
    		case "up", "k":
    			if ft.focus > 0 {
    				ft.focus--
    			}
    		case "down", "j":
    			if ft.focus < len(ft.fields)-1 {
    				ft.focus++
    			}
    		case "enter":
    			if ft.focus == len(ft.fields)-1 {
    				// Submit form
    				if ft.validateForm() {
    					ft.submitting = true
    					values := ft.getFormValues()
    					if ft.onSubmit != nil {
    						return ft, ft.onSubmit(values)
    					}
    				}
    			} else {
    				ft.focus = (ft.focus + 1) % len(ft.fields)
    			}
    		case "esc":
    			if ft.onCancel != nil {
    				return ft, ft.onCancel()
    			}
    		default:
    			// Handle text input
    			if len(msg.Runes) > 0 {
    				ft.fields[ft.focus].Value += string(msg.Runes)
    			} else if msg.Type == tea.KeyBackspace {
    				if len(ft.fields[ft.focus].Value) > 0 {
    					ft.fields[ft.focus].Value =
    						ft.fields[ft.focus].Value[:len(ft.fields[ft.focus].Value)-1]
    				}
    			}
    		}
    	}
    	return ft, nil
    }

    func (ft *FormTemplate) View() string {
    	if ft.submitting {
    		return "Submitting..."
    	}

    	var output strings.Builder

    	// Title
    	output.WriteString(fmt.Sprintf("📝 %s\n\n", ft.title))

    	// Fields
    	for i, field := range ft.fields {
    		cursor := "  "
    		if i == ft.focus {
    			cursor = "▶ "
    		}

    		value := field.Value
    		if value == "" && i != ft.focus {
    			value = fmt.Sprintf("\x1b[2m%s\x1b[0m", field.Placeholder)
    		}

    		output.WriteString(fmt.Sprintf("%s%s: [%s]\n",
    			cursor, field.Label, value))
    	}

    	// Actions
    	output.WriteString("\n[Enter] Submit  [Esc] Cancel")

    	// Error
    	if ft.error != nil {
    		output.WriteString(fmt.Sprintf("\n\n❌ %s", ft.error))
    	}

    	return output.String()
    }

    func (ft *FormTemplate) validateForm() bool {
    	for _, field := range ft.fields {
    		if field.Required && field.Value == "" {
    			ft.error = fmt.Errorf("%s is required", field.Label)
    			return false
    		}
    		if field.Validation != nil {
    			if err := field.Validation(field.Value); err != nil {
    				ft.error = err
    				return false
    			}
    		}
    	}
    	ft.error = nil
    	return true
    }

    func (ft *FormTemplate) getFormValues() map[string]string {
    	values := make(map[string]string)
    	for _, field := range ft.fields {
    		values[field.ID] = field.Value
    	}
    	return values
    }

    func getBoolValue(m map[string]interface{}, key string, defaultValue bool) bool {
    	if val, ok := m[key]; ok {
    		if bl, ok := val.(bool); ok {
    			return bl
    		}
    	}
    	return defaultValue
    }
  '';
in
pkgs.writeText "form.go" formCode
