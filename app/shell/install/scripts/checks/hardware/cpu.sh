#!/usr/bin/env bash



log_section "Detecting CPU Configuration"

# CPU Information
log_info "Processor Information:"
if [ -f "/proc/cpuinfo" ]; then
    # CPU Model
    model_name=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2- | sed 's/^[ \t]*//')
    cpu_cores=$(grep "cpu cores" /proc/cpuinfo | head -n1 | cut -d: -f2- | sed 's/^[ \t]*//')
    cpu_threads=$(grep -c "^processor" /proc/cpuinfo)
    
    echo -e "  Model    : ${CYAN}${model_name}${NC}"
    echo -e "  Cores    : ${CYAN}${cpu_cores}${NC} physical"
    echo -e "  Threads  : ${CYAN}${cpu_threads}${NC} logical"
    
    # CPU Frequency
    if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]; then
        current_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        current_freq_ghz=$(awk "BEGIN {printf \"%.2f\", $current_freq/1000000}")
        echo -e "  Current  : ${CYAN}${current_freq_ghz}${NC} GHz"
        
        min_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)
        min_freq_ghz=$(awk "BEGIN {printf \"%.2f\", $min_freq/1000000}")
        max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
        max_freq_ghz=$(awk "BEGIN {printf \"%.2f\", $max_freq/1000000}")
        echo -e "  Range    : ${GRAY}${min_freq_ghz} - ${max_freq_ghz}${NC} GHz"
        
        governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "  Governor : ${CYAN}${governor}${NC}"
    else
        cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -n1 | cut -d: -f2- | sed 's/^[ \t]*//' | cut -d. -f1)
        cpu_freq_ghz=$(awk "BEGIN {printf \"%.2f\", $cpu_freq/1000}")
        echo -e "  Clock    : ${CYAN}${cpu_freq_ghz}${NC} GHz"
    fi
    
    # CPU Features
    echo -e "  Features :"
    features=$(grep "flags" /proc/cpuinfo | head -n1 | cut -d: -f2-)
    # Wichtige CPU-Features prüfen
    for feature in "vmx" "svm" "avx" "avx2" "sse4_2" "aes" "hypervisor"; do
        if echo "$features" | grep -q "$feature"; then
            case $feature in
                "vmx") echo -e "    ${GREEN}✓${NC} Intel VT-x";;
                "svm") echo -e "    ${GREEN}✓${NC} AMD-V";;
                "avx") echo -e "    ${GREEN}✓${NC} AVX";;
                "avx2") echo -e "    ${GREEN}✓${NC} AVX2";;
                "sse4_2") echo -e "    ${GREEN}✓${NC} SSE4.2";;
                "aes") echo -e "    ${GREEN}✓${NC} AES-NI";;
                "hypervisor") echo -e "    ${YELLOW}!${NC} Running in VM";;
            esac
        fi
    done
    
    # CPU Temperature (wenn verfügbar)
    if command -v sensors &> /dev/null; then
        echo -e "  Temperature:"
        sensors | grep -E "Core|Package|Tdie" | while read -r line; do
            temp_name=$(echo "$line" | awk '{print $1" "$2}' | sed 's/:$//')
            temp_value=$(echo "$line" | grep -o '+[0-9.]\+°C' | head -n1)
            if [ -n "$temp_value" ]; then
                temp_num=$(echo "$temp_value" | grep -o '[0-9.]\+' | cut -d. -f1)
                # Farbkodierung basierend auf Temperatur
                if [ "$temp_num" -gt 80 ]; then
                    temp_color=$RED
                elif [ "$temp_num" -gt 60 ]; then
                    temp_color=$YELLOW
                else
                    temp_color=$GREEN
                fi
                echo -e "    ${GRAY}${temp_name}${NC}: ${temp_color}${temp_value}${NC}"
            fi
        done
    fi
else
    echo -e "  ${RED}Could not read CPU information${NC}"
fi