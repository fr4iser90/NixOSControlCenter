{ lib, colors }:

with lib;

{
  # Direkte Funktionen statt verschachteltem prompt-Objekt
  yesNo = question: ''
    read -p "${question} (j/N) " answer
    case $answer in
      [Jj]* ) return 0;;
      * ) return 1;;
    esac
  '';

  select = options: prompt: ''
    PS3="${prompt}: "
    select opt in "''${options[@]}"; do
      if [ -n "$opt" ]; then
        printf '%s\n' "$opt"
        break
      fi
    done
  '';

  input = prompt: ''
    read -p "${prompt}: " input
    printf '%s\n' "$input"
  '';

  text = prompt: ''${prompt}: '';

  prompt = text: ''${text}: '';

  confirm = question: defaultYes: let
    isYes = if builtins.isBool defaultYes 
      then defaultYes 
      else defaultYes == "y" || defaultYes == "Y" || defaultYes == "true";
    prompt = if isYes 
      then "${question} [Y/n]"
      else "${question} [y/N]";
  in ''
    read -p "${prompt} " response
    case $response in
      [Yy]* ) return 0;;
      [Nn]* ) return 1;;
      * ) ${if isYes then "return 0" else "return 1"};;
    esac
  '';
}