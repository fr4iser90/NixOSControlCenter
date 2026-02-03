{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.privacy.faceBlur;
in
{
  options.services.chronicle.privacy.faceBlur = {
    enable = mkEnableOption "face blurring for screenshots";

    backend = mkOption {
      type = types.enum [ "opencv" "dlib" ];
      default = "opencv";
      description = "Backend to use for face detection";
    };

    blurStrength = mkOption {
      type = types.ints.between 1 100;
      default = 50;
      description = "Strength of blur effect (1-100)";
    };

    realTimeBlur = mkOption {
      type = types.bool;
      default = true;
      description = "Apply blur during recording vs post-processing";
    };

    detectionConfidence = mkOption {
      type = types.float;
      default = 0.7;
      description = "Minimum confidence threshold for face detection (0.0-1.0)";
    };

    modelPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Custom model path for face detection";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (python3.withPackages (ps: with ps; [
        opencv4
      ] ++ optionals (cfg.backend == "dlib") [
        dlib
      ]))
      (pkgs.writeShellScriptBin "chronicle-face-blur" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Face Blur Script
      # Detects and blurs faces in screenshots

      SCREENSHOT="$1"
      OUTPUT="''${2:-$SCREENSHOT}"
      BLUR_STRENGTH="${toString cfg.blurStrength}"
      CONFIDENCE="${toString cfg.detectionConfidence}"
      BACKEND="${cfg.backend}"

      ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
      import cv2
      import sys
      import os

      def blur_faces_opencv(image_path, output_path, blur_strength, confidence):
          """Blur faces using OpenCV Haar Cascades"""
          img = cv2.imread(image_path)
          if img is None:
              print(f"Error: Could not read image {image_path}", file=sys.stderr)
              return False
          
          gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
          
          # Load pre-trained face detection model
          face_cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
          face_cascade = cv2.CascadeClassifier(face_cascade_path)
          
          # Detect faces
          faces = face_cascade.detectMultiScale(
              gray,
              scaleFactor=1.1,
              minNeighbors=5,
              minSize=(30, 30)
          )
          
          # Blur each detected face
          for (x, y, w, h) in faces:
              # Extract face region
              face_region = img[y:y+h, x:x+w]
              
              # Calculate kernel size based on blur strength
              kernel_size = max(3, int((blur_strength / 100) * 99))
              if kernel_size % 2 == 0:
                  kernel_size += 1
              
              # Apply Gaussian blur
              blurred_face = cv2.GaussianBlur(face_region, (kernel_size, kernel_size), 0)
              
              # Replace face region with blurred version
              img[y:y+h, x:x+w] = blurred_face
          
          # Save result
          cv2.imwrite(output_path, img)
          print(f"Blurred {len(faces)} face(s) in {image_path}")
          return True

      if __name__ == "__main__":
          image = os.environ.get('SCREENSHOT', sys.argv[1] if len(sys.argv) > 1 else None)
          output = os.environ.get('OUTPUT', sys.argv[2] if len(sys.argv) > 2 else image)
          blur = float(os.environ.get('BLUR_STRENGTH', '50'))
          conf = float(os.environ.get('CONFIDENCE', '0.7'))
          backend = os.environ.get('BACKEND', 'opencv')
          
          if backend == 'opencv':
              success = blur_faces_opencv(image, output, blur, conf)
              sys.exit(0 if success else 1)
          else:
              print(f"Backend {backend} not yet implemented", file=sys.stderr)
              sys.exit(1)
      PYTHON_EOF
      '')
    ];
  };
}
