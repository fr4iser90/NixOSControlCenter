# Example processor: Transforms collected data
# Processors filter, map, aggregate, normalize, enrich data

{ pkgs, lib, ... }:

{
  process = input: ''
    # Example: Filter data
    # FILTERED=$(echo "$input" | grep "pattern")
    
    # Example: Transform data
    # TRANSFORMED=$(echo "$input" | sed 's/old/new/')
    
    # Example: Aggregate data
    # COUNT=$(echo "$input" | wc -l)
    
    # Return transformed data
    echo "$input" | tr '[:lower:]' '[:upper:]'
  '';
}

