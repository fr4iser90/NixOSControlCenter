# Example validator: Validates data correctness
# Validators check format, constraints, business rules

{ pkgs, lib, ui, ... }:

{
  validate = input: ''
    # Example: Check format
    if ! echo "$input" | grep -q "^[0-9]\+$"; then
      ${ui.messages.error "Invalid format: must be numeric"}
      exit 1
    fi
    
    # Example: Check constraints
    if [ "$input" -lt 0 ] || [ "$input" -gt 100 ]; then
      ${ui.messages.error "Value out of range: must be 0-100"}
      exit 1
    fi
    
    # Example: Check business rules
    # if [ "$input" = "invalid" ]; then
    #   ${ui.messages.error "Invalid value"}
    #   exit 1
    # fi
    
    ${ui.messages.success "Validation passed"}
  '';
}

