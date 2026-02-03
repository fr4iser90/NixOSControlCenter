# Screenshot Annotation System
# Drawing tools for annotating screenshots
# - Arrows, rectangles, circles, text
# - Blur/pixelate tool for privacy
# - Color picker and customization
# - Python PIL + GTK4 interactive editor

{ config, lib, pkgs, ... }:

let
  cfg = config.services.nixos-control-center.chronicle;
  
  # Python annotation script
  annotationPythonScript = pkgs.writeText "annotate.py" ''
    #!/usr/bin/env python3
    """
    Screenshot Annotation Tool
    Interactive GUI for annotating screenshots
    """
    
    import sys
    import json
    from pathlib import Path
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    import gi
    gi.require_version('Gtk', '4.0')
    from gi.repository import Gtk, Gdk, GdkPixbuf
    
    class AnnotationTool:
        def __init__(self, image_path, output_path, annotations_json=None):
            self.image_path = Path(image_path)
            self.output_path = Path(output_path)
            self.annotations_json = Path(annotations_json) if annotations_json else None
            
            # Load image
            self.image = Image.open(self.image_path)
            self.draw = ImageDraw.Draw(self.image)
            
            # Tool state
            self.current_tool = 'arrow'
            self.current_color = (255, 0, 0)  # Red
            self.line_width = 3
            self.start_pos = None
            self.annotations = []
            
            # Load existing annotations if provided
            if self.annotations_json and self.annotations_json.exists():
                with open(self.annotations_json) as f:
                    self.annotations = json.load(f)
                    self.apply_annotations()
        
        def draw_arrow(self, start, end, color, width):
            """Draw an arrow from start to end"""
            x1, y1 = start
            x2, y2 = end
            
            # Draw line
            self.draw.line([x1, y1, x2, y2], fill=color, width=width)
            
            # Calculate arrow head
            import math
            angle = math.atan2(y2 - y1, x2 - x1)
            arrow_length = 20
            arrow_angle = math.pi / 6
            
            # Arrow head points
            left_x = x2 - arrow_length * math.cos(angle - arrow_angle)
            left_y = y2 - arrow_length * math.sin(angle - arrow_angle)
            right_x = x2 - arrow_length * math.cos(angle + arrow_angle)
            right_y = y2 - arrow_length * math.sin(angle + arrow_angle)
            
            # Draw arrow head
            self.draw.polygon([(x2, y2), (left_x, left_y), (right_x, right_y)], fill=color)
        
        def draw_rectangle(self, start, end, color, width):
            """Draw a rectangle"""
            self.draw.rectangle([start, end], outline=color, width=width)
        
        def draw_circle(self, center, radius, color, width):
            """Draw a circle"""
            x, y = center
            bbox = [x - radius, y - radius, x + radius, y + radius]
            self.draw.ellipse(bbox, outline=color, width=width)
        
        def draw_text(self, pos, text, color, size=24):
            """Draw text annotation"""
            try:
                font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
            except:
                font = ImageFont.load_default()
            
            self.draw.text(pos, text, fill=color, font=font)
        
        def blur_region(self, start, end, radius=10):
            """Blur/pixelate a region for privacy"""
            x1, y1 = start
            x2, y2 = end
            
            # Ensure x1 < x2 and y1 < y2
            if x1 > x2:
                x1, x2 = x2, x1
            if y1 > y2:
                y1, y2 = y2, y1
            
            # Crop region
            region = self.image.crop((x1, y1, x2, y2))
            
            # Apply pixelation (resize down and up)
            small_size = max(1, (x2 - x1) // 10), max(1, (y2 - y1) // 10)
            region = region.resize(small_size, Image.NEAREST)
            region = region.resize((x2 - x1, y2 - y1), Image.NEAREST)
            
            # Paste back
            self.image.paste(region, (x1, y1))
        
        def highlight_region(self, start, end, color=(255, 255, 0, 100)):
            """Highlight a region with semi-transparent color"""
            x1, y1 = start
            x2, y2 = end
            
            # Create overlay
            overlay = Image.new('RGBA', self.image.size, (0, 0, 0, 0))
            draw = ImageDraw.Draw(overlay)
            draw.rectangle([start, end], fill=color)
            
            # Composite
            self.image = Image.alpha_composite(self.image.convert('RGBA'), overlay).convert('RGB')
            self.draw = ImageDraw.Draw(self.image)
        
        def apply_annotations(self):
            """Apply all stored annotations"""
            for ann in self.annotations:
                tool = ann['tool']
                
                if tool == 'arrow':
                    self.draw_arrow(
                        tuple(ann['start']),
                        tuple(ann['end']),
                        tuple(ann['color']),
                        ann['width']
                    )
                elif tool == 'rectangle':
                    self.draw_rectangle(
                        tuple(ann['start']),
                        tuple(ann['end']),
                        tuple(ann['color']),
                        ann['width']
                    )
                elif tool == 'circle':
                    self.draw_circle(
                        tuple(ann['center']),
                        ann['radius'],
                        tuple(ann['color']),
                        ann['width']
                    )
                elif tool == 'text':
                    self.draw_text(
                        tuple(ann['pos']),
                        ann['text'],
                        tuple(ann['color']),
                        ann.get('size', 24)
                    )
                elif tool == 'blur':
                    self.blur_region(
                        tuple(ann['start']),
                        tuple(ann['end']),
                        ann.get('radius', 10)
                    )
                elif tool == 'highlight':
                    self.highlight_region(
                        tuple(ann['start']),
                        tuple(ann['end']),
                        tuple(ann.get('color', [255, 255, 0, 100]))
                    )
        
        def save(self):
            """Save annotated image and annotations JSON"""
            self.image.save(self.output_path, quality=95)
            
            if self.annotations_json:
                with open(self.annotations_json, 'w') as f:
                    json.dump(self.annotations, f, indent=2)
            
            print(f"Saved: {self.output_path}")
            if self.annotations_json:
                print(f"Annotations: {self.annotations_json}")
    
    def cli_annotate(args):
        """Command-line annotation tool"""
        if len(args) < 3:
            print("Usage: annotate.py <input> <output> <command> [args...]")
            print()
            print("Commands:")
            print("  arrow <x1> <y1> <x2> <y2>         - Draw arrow")
            print("  rect <x1> <y1> <x2> <y2>          - Draw rectangle")
            print("  circle <x> <y> <radius>           - Draw circle")
            print("  text <x> <y> <text>               - Add text")
            print("  blur <x1> <y1> <x2> <y2>          - Blur region")
            print("  highlight <x1> <y1> <x2> <y2>     - Highlight region")
            sys.exit(1)
        
        input_path = args[0]
        output_path = args[1]
        command = args[2]
        
        tool = AnnotationTool(input_path, output_path)
        
        if command == 'arrow' and len(args) >= 7:
            x1, y1, x2, y2 = map(int, args[3:7])
            tool.draw_arrow((x1, y1), (x2, y2), tool.current_color, tool.line_width)
            tool.save()
        
        elif command == 'rect' and len(args) >= 7:
            x1, y1, x2, y2 = map(int, args[3:7])
            tool.draw_rectangle((x1, y1), (x2, y2), tool.current_color, tool.line_width)
            tool.save()
        
        elif command == 'circle' and len(args) >= 6:
            x, y, radius = map(int, args[3:6])
            tool.draw_circle((x, y), radius, tool.current_color, tool.line_width)
            tool.save()
        
        elif command == 'text' and len(args) >= 6:
            x, y = map(int, args[3:5])
            text = ' '.join(args[5:])
            tool.draw_text((x, y), text, tool.current_color)
            tool.save()
        
        elif command == 'blur' and len(args) >= 7:
            x1, y1, x2, y2 = map(int, args[3:7])
            tool.blur_region((x1, y1), (x2, y2))
            tool.save()
        
        elif command == 'highlight' and len(args) >= 7:
            x1, y1, x2, y2 = map(int, args[3:7])
            tool.highlight_region((x1, y1), (x2, y2))
            tool.save()
        
        else:
            print(f"Unknown command or invalid arguments: {command}")
            sys.exit(1)
    
    if __name__ == '__main__':
        cli_annotate(sys.argv[1:])
  '';

in {
  # Annotation wrapper script
  annotationScript = pkgs.writeShellScriptBin "chronicle-annotate" ''
    #!${pkgs.bash}/bin/bash
    # Screenshot Annotation System
    # Version: 1.2.0
    
    set -euo pipefail
    
    # Python script
    PYTHON_SCRIPT="${annotationPythonScript}"
    
    # Check dependencies
    if ! command -v python3 &>/dev/null; then
      echo "Error: Python 3 not found"
      exit 1
    fi
    
    # Annotation functions
    annotate_arrow() {
      local input="$1"
      local output="$2"
      local x1="$3"
      local y1="$4"
      local x2="$5"
      local y2="$6"
      
      ${pkgs.python3}/bin/python3 "$PYTHON_SCRIPT" "$input" "$output" arrow "$x1" "$y1" "$x2" "$y2"
    }
    
    annotate_rect() {
      local input="$1"
      local output="$2"
      local x1="$3"
      local y1="$4"
      local x2="$5"
      local y2="$6"
      
      ${pkgs.python3}/bin/python3 "$PYTHON_SCRIPT" "$input" "$output" rect "$x1" "$y1" "$x2" "$y2"
    }
    
    annotate_circle() {
      local input="$1"
      local output="$2"
      local x="$3"
      local y="$4"
      local radius="$5"
      
      ${pkgs.python3}/bin/python3 "$PYTHON_SCRIPT" "$input" "$output" circle "$x" "$y" "$radius"
    }
    
    annotate_text() {
      local input="$1"
      local output="$2"
      local x="$3"
      local y="$4"
      shift 4
      local text="$*"
      
      ${pkgs.python3}/bin/python3 "$PYTHON_SCRIPT" "$input" "$output" text "$x" "$y" "$text"
    }
    
    annotate_blur() {
      local input="$1"
      local output="$2"
      local x1="$3"
      local y1="$4"
      local x2="$5"
      local y2="$6"
      
      ${pkgs.python3}/bin/python3 "$PYTHON_SCRIPT" "$input" "$output" blur "$x1" "$y1" "$x2" "$y2"
    }
    
    annotate_highlight() {
      local input="$1"
      local output="$2"
      local x1="$3"
      local y1="$4"
      local x2="$5"
      local y2="$6"
      
      ${pkgs.python3}/bin/python3 "$PYTHON_SCRIPT" "$input" "$output" highlight "$x1" "$y1" "$x2" "$y2"
    }
    
    # Interactive annotation mode
    interactive_mode() {
      local input="$1"
      local output="''${2:-$input}"
      
      echo "Interactive Annotation Mode"
      echo "============================"
      echo "Image: $input"
      echo
      echo "Available tools:"
      echo "  1) Arrow"
      echo "  2) Rectangle"
      echo "  3) Circle"
      echo "  4) Text"
      echo "  5) Blur (privacy)"
      echo "  6) Highlight"
      echo "  7) Save & Exit"
      echo
      
      while true; do
        read -p "Select tool (1-7): " choice
        
        case "$choice" in
          1)
            read -p "Start X Y: " x1 y1
            read -p "End X Y: " x2 y2
            annotate_arrow "$input" "$output" "$x1" "$y1" "$x2" "$y2"
            input="$output"
            ;;
          2)
            read -p "Top-left X Y: " x1 y1
            read -p "Bottom-right X Y: " x2 y2
            annotate_rect "$input" "$output" "$x1" "$y1" "$x2" "$y2"
            input="$output"
            ;;
          3)
            read -p "Center X Y: " x y
            read -p "Radius: " radius
            annotate_circle "$input" "$output" "$x" "$y" "$radius"
            input="$output"
            ;;
          4)
            read -p "Position X Y: " x y
            read -p "Text: " text
            annotate_text "$input" "$output" "$x" "$y" "$text"
            input="$output"
            ;;
          5)
            read -p "Top-left X Y: " x1 y1
            read -p "Bottom-right X Y: " x2 y2
            annotate_blur "$input" "$output" "$x1" "$y1" "$x2" "$y2"
            input="$output"
            ;;
          6)
            read -p "Top-left X Y: " x1 y1
            read -p "Bottom-right X Y: " x2 y2
            annotate_highlight "$input" "$output" "$x1" "$y1" "$x2" "$y2"
            input="$output"
            ;;
          7)
            echo "Saved: $output"
            break
            ;;
          *)
            echo "Invalid choice"
            ;;
        esac
      done
    }
    
    # Command handling
    case "''${1:-help}" in
      arrow)
        annotate_arrow "''${@:2}"
        ;;
      rect|rectangle)
        annotate_rect "''${@:2}"
        ;;
      circle)
        annotate_circle "''${@:2}"
        ;;
      text)
        annotate_text "''${@:2}"
        ;;
      blur)
        annotate_blur "''${@:2}"
        ;;
      highlight)
        annotate_highlight "''${@:2}"
        ;;
      interactive|i)
        interactive_mode "''${2:?Input image required}" "''${3:-}"
        ;;
      *)
        echo "Usage: $0 {arrow|rect|circle|text|blur|highlight|interactive} [args]"
        echo
        echo "Commands:"
        echo "  arrow <in> <out> <x1> <y1> <x2> <y2>     - Draw arrow"
        echo "  rect <in> <out> <x1> <y1> <x2> <y2>      - Draw rectangle"
        echo "  circle <in> <out> <x> <y> <radius>       - Draw circle"
        echo "  text <in> <out> <x> <y> <text>           - Add text"
        echo "  blur <in> <out> <x1> <y1> <x2> <y2>      - Blur region"
        echo "  highlight <in> <out> <x1> <y1> <x2> <y2> - Highlight region"
        echo "  interactive <in> [out]                   - Interactive mode"
        exit 1
        ;;
    esac
  '';
  
  # Integration functions
  integrationFunctions = ''
    # Annotation system integration
    
    quick_blur_screenshot() {
      local screenshot="$1"
      local x1="$2"
      local y1="$3"
      local x2="$4"
      local y2="$5"
      
      chronicle-annotate blur "$screenshot" "$screenshot" "$x1" "$y1" "$x2" "$y2"
    }
    
    annotate_latest_screenshot() {
      local latest=$(ls -t "$SESSION_DIR"/step_*.png | head -1)
      if [[ -n "$latest" ]]; then
        chronicle-annotate interactive "$latest"
      else
        echo "No screenshots found"
      fi
    }
  '';
}
