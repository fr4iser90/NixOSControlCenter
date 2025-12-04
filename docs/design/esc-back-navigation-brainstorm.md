# ESC Back Navigation: Brainstorming

## 📋 Current Behavior

**Current Flow:**
```
1. User selects: "📦 Presets"
2. User selects: "Homelab Server"
3. User presses ESC → Setup aborted ❌
```

**Problem:**
- ESC cancels everything
- No way to go back one step
- User has to start over

---

## 💡 Solution Options

### Option 1: ESC = Go Back (State Machine)

**How it works:**
- Track current "step" in navigation
- ESC returns to previous step
- Only abort if ESC pressed at first step

**Implementation:**
```bash
select_setup_mode() {
    local step=1
    local install_type_choice
    
    while true; do
        case $step in
            1)
                # Step 1: Installation type
                install_type_choice=$(printf "%s\n" "${INSTALL_TYPE_OPTIONS[@]}" | fzf \
                    --header="Choose installation method (ESC to exit)" \
                    --bind 'esc:cancel' \
                    --expect=esc) || return 1
                
                # Check if ESC was pressed
                if [[ "$install_type_choice" == *"esc"* ]]; then
                    return 1  # Exit completely
                fi
                
                step=2
                ;;
            2)
                # Step 2: Preset selection
                if [[ "$install_type_choice" == "📦 Presets" ]]; then
                    preset_choice=$(printf "%b" "$preset_list" | fzf \
                        --header="Select preset (ESC to go back)" \
                        --bind 'esc:abort' \
                        --expect=esc) || {
                        # ESC pressed → go back to step 1
                        step=1
                        continue
                    }
                    
                    # Check if ESC was pressed
                    if [[ "$preset_choice" == *"esc"* ]]; then
                        step=1
                        continue
                    fi
                fi
                break
                ;;
        esac
    done
}
```

**Pros:**
- ✅ Natural navigation (ESC = back)
- ✅ User can correct mistakes
- ✅ Better UX

**Cons:**
- ⚠️ More complex (state machine needed)
- ⚠️ Need to track navigation stack

---

### Option 2: ESC with `--expect` (fzf Feature)

**How it works:**
- Use fzf's `--expect` to detect ESC
- Return special value when ESC pressed
- Handle "BACK" vs "CANCEL" based on step

**Implementation:**
```bash
select_preset() {
    local preset_list="..."
    local result
    
    result=$(printf "%b" "$preset_list" | fzf \
        --header="Select preset (ESC to go back)" \
        --expect=esc,ctrl-b \
        --bind 'ctrl-b:abort') || return 1
    
    # Parse result
    local key=$(echo "$result" | head -1)
    local choice=$(echo "$result" | tail -1)
    
    if [[ "$key" == "esc" ]]; then
        echo "BACK"  # Signal to go back
        return 0
    fi
    
    echo "$choice"
    return 0
}
```

**Pros:**
- ✅ Uses fzf's built-in `--expect`
- ✅ Can distinguish ESC from other keys
- ✅ Clean separation

**Cons:**
- ⚠️ Need to handle "BACK" signal in caller
- ⚠️ More complex error handling

---

### Option 3: Two ESC Presses (Like Vim)

**How it works:**
- First ESC: Show "Go back? (Press ESC again to exit)"
- Second ESC: Exit completely

**Implementation:**
```bash
select_with_back() {
    local options=("$@")
    local esc_state="normal"  # State: normal, esc_once, esc_twice
    
    while true; do
        local result
        local header_text
        
        case "$esc_state" in
            "normal")
                header_text="Select option (ESC to go back)"
                ;;
            "esc_once")
                header_text="Go back? (Press ESC again to exit)"
                ;;
        esac
        
        result=$(printf "%s\n" "${options[@]}" | fzf \
            --header="$header_text" \
            --expect=esc) || {
            # fzf exited
            if [[ "$esc_state" == "esc_once" ]]; then
                # Second ESC → exit completely
                return 1
            fi
            return 1
        }
        
        local key=$(echo "$result" | head -1)
        local choice=$(echo "$result" | tail -1)
        
        if [[ "$key" == "esc" ]]; then
            if [[ "$esc_state" == "normal" ]]; then
                # First ESC → show prompt, wait for second
                esc_state="esc_once"
                continue
            elif [[ "$esc_state" == "esc_once" ]]; then
                # Second ESC → exit completely
                return 1
            fi
        else
            # Valid selection
            echo "$choice"
            return 0
        fi
    done
}
```

**Pros:**
- ✅ Prevents accidental exits
- ✅ Clear feedback

**Cons:**
- ❌ Two key presses (slower)
- ❌ **More complex** (needs state machine with 3 states: normal, esc_once, esc_twice)
- ❌ **Actually MORE complex than Option 1** (extra intermediate state)

---

### Option 4: Separate "Back" Option in List

**How it works:**
- Add "← Back" option at top of every list
- User selects it to go back
- No ESC needed

**Implementation:**
```bash
select_preset() {
    local preset_list=""
    preset_list+="← Back\n"  # Add back option
    preset_list+="🖥️  System Presets\n"
    # ... rest of presets
    
    local choice=$(printf "%b" "$preset_list" | fzf ...)
    
    if [[ "$choice" == "← Back" ]]; then
        return 2  # Special return code for "back"
    fi
    
    echo "$choice"
}
```

**Pros:**
- ✅ Very explicit
- ✅ No special key handling
- ✅ Works everywhere

**Cons:**
- ❌ Takes up list space
- ❌ Less "natural" than ESC

---

## 🎯 Recommendation: Option 1 + Option 2 Hybrid

**Best Approach:**
- Use `--expect=esc` to detect ESC
- Track navigation stack
- ESC at first step = Exit
- ESC at later steps = Go back

**Implementation Pattern:**
```bash
select_setup_mode() {
    local navigation_stack=()
    local current_step="install_type"
    
    while true; do
        case "$current_step" in
            "install_type")
                local result
                result=$(printf "%s\n" "${INSTALL_TYPE_OPTIONS[@]}" | fzf \
                    --header="Choose installation method (ESC to exit)" \
                    --expect=esc) || return 1
                
                local key=$(echo "$result" | head -1)
                local choice=$(echo "$result" | tail -1)
                
                if [[ "$key" == "esc" ]]; then
                    return 1  # Exit completely
                fi
                
                navigation_stack+=("install_type:$choice")
                current_step="preset"
                ;;
                
            "preset")
                local result
                result=$(printf "%b" "$preset_list" | fzf \
                    --header="Select preset (ESC to go back)" \
                    --expect=esc) || {
                    # ESC or cancel → go back
                    if [[ ${#navigation_stack[@]} -gt 0 ]]; then
                        navigation_stack=("${navigation_stack[@]:0:-1}")  # Pop
                        current_step="install_type"
                        continue
                    fi
                    return 1
                }
                
                local key=$(echo "$result" | head -1)
                local choice=$(echo "$result" | tail -1)
                
                if [[ "$key" == "esc" ]]; then
                    # Go back to previous step
                    navigation_stack=("${navigation_stack[@]:0:-1}")
                    current_step="install_type"
                    continue
                fi
                
                # Process choice...
                break
                ;;
        esac
    done
}
```

---

## 🔧 fzf ESC Handling

**fzf Behavior:**
- Default: ESC exits fzf with exit code 1
- With `--expect=esc`: ESC returns "esc" as first line
- Can distinguish between ESC and other exits

**Key Points:**
- `--expect=esc` captures ESC key
- Output format: `KEY\nSELECTION`
- Can check first line for "esc"

---

## ✅ Final Recommendation

**Use Option 3 (Double ESC Pattern) with Centralized State Machine:**

1. **Centralized `state-machine.sh`** module for all prompts
2. **Double ESC pattern**: First ESC = "Go back?", Second ESC = "Exit completely"
3. **Navigation stack tracking** (where user came from)
4. **Reusable functions** for all setup prompts
5. **Long-term maintainability** (single source of truth)

**Benefits:**
- ✅ Prevents accidental exits (double confirmation)
- ✅ Better UX (clear feedback)
- ✅ Centralized management (easier to maintain)
- ✅ Reusable across all prompts
- ✅ Long-term scalability

**Implementation:**
- ✅ **Created**: `shell/scripts/ui/prompts/state-machine.sh`
- ✅ Provides: `fzf_with_back()`, `fzf_multi_with_back()`, `prompt_select()`, `prompt_multi_select()`
- ✅ Handles: Navigation stack, ESC state (normal → esc_once → exit), Back/Exit logic

**Usage Example:**
```bash
source "$DOCKER_SCRIPTS_DIR/ui/prompts/state-machine.sh"

init_state_machine

# Single select with back navigation
result=$(prompt_select "install_type" INSTALL_TYPE_OPTIONS \
    "Choose installation method" "$PREVIEW_SCRIPT")

if [[ "$result" == "BACK" ]]; then
    # Handle back navigation
elif [[ "$result" == "EXIT" ]]; then
    # Handle exit
else
    # Process selection
fi
```

---

## 📊 Comparison

| Option | Natural | Complexity | UX | Notes |
|--------|---------|------------|-----|-------|
| Option 1 (State Machine) | ⭐⭐⭐ | ⭐⭐ Medium | ⭐⭐⭐ Best | Navigation stack tracking |
| Option 2 (--expect) | ⭐⭐⭐ | ⭐⭐ Medium | ⭐⭐⭐ Best | Same as Option 1, different approach |
| **Option 3 (Double ESC)** | ⭐⭐ | ⭐⭐⭐ **More Complex** | ⭐⭐⭐ **Best** | **Centralized state-machine.sh** ✅ |
| Option 4 (Back Option) | ⭐ | ⭐ Easy | ⭐⭐ Good | No state machine needed |

**Winner: Option 3 (Double ESC) with Centralized State Machine** ✅

**Why Option 3?**
- ✅ **Long-term maintainability**: Centralized `state-machine.sh` module
- ✅ **Prevents accidental exits**: Double confirmation required
- ✅ **Reusable**: All prompts use same functions
- ✅ **Scalable**: Easy to add new prompts
- ✅ **Clear feedback**: User knows what ESC will do

**Note:** While Option 3 requires a 3-state machine (normal → esc_once → exit), the **centralized implementation** in `state-machine.sh` makes it manageable and reusable across all prompts.

---

## 🔧 Implementation Example

**Before (setup-mode.sh):**
```bash
install_type_choice=$(printf "%s\n" "${INSTALL_TYPE_OPTIONS[@]}" | fzf \
    --header="Choose installation method" \
    --bind 'space:accept' \
    --preview "$PREVIEW_SCRIPT {}" \
    --preview-window="right:50%:wrap" \
    --pointer="▶" \
    --marker="✓") || { log_error "Cancelled."; return 1; }
```

**After (with state-machine.sh):**
```bash
source "$DOCKER_SCRIPTS_DIR/ui/prompts/state-machine.sh"

init_state_machine

# Step 1: Installation type
while true; do
    result=$(prompt_select "install_type" INSTALL_TYPE_OPTIONS \
        "Choose installation method" "$PREVIEW_SCRIPT")
    
    if [[ "$result" == "BACK" ]]; then
        # Already at first step, exit completely
        return 1
    elif [[ "$result" == "EXIT" ]]; then
        return 1
    else
        install_type_choice="$result"
        break
    fi
done

# Step 2: Preset selection (if Presets chosen)
if [[ "$install_type_choice" == "📦 Presets" ]]; then
    while true; do
        result=$(prompt_select "preset" PRESET_OPTIONS \
            "Select preset" "$PREVIEW_SCRIPT")
        
        if [[ "$result" == "BACK" ]]; then
            # Go back to install type selection
            continue  # Loop back to Step 1
        elif [[ "$result" == "EXIT" ]]; then
            return 1
        else
            preset_choice="$result"
            break
        fi
    done
fi
```

**Benefits:**
- ✅ Consistent ESC handling across all prompts
- ✅ Easy to add new steps
- ✅ Centralized navigation logic
- ✅ Long-term maintainability

