validate_generation() {
  local gen=$1
  # Check if number and within reasonable range
  if ! [[ $gen =~ ^[0-9]+$ ]] || [ $gen -lt 1 ] || [ $gen -gt 999 ]; then
    echo "Invalid generation number: $gen"
    return 1
  fi
  return 0
}

validate_name() {
  local name=$1
  # Allow only alphanumeric, dash, underscore and space
  if ! [[ $name =~ ^[a-zA-Z0-9_\ -]+$ ]]; then
    echo "Invalid name format: $name"
    return 1
  fi
  return 0
}
