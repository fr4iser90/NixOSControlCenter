# Embed WPA PSK into a NetworkManager keyfile (headless-safe)
{ pkgs }:

pkgs.writeScript "ncc-embed-wifi-psk" ''
  #!${pkgs.python3}/bin/python3
  import re
  import sys


  def main() -> int:
      if len(sys.argv) != 3:
          return 1
      path, psk = sys.argv[1], sys.argv[2]
      if not psk or psk == "--":
          return 0
      with open(path, encoding="utf-8", errors="replace") as f:
          content = f.read()
      if not re.search(r"^\[connection\]", content, re.M):
          content = "[connection]\nautoconnect=true\n" + content
      elif not re.search(r"(?m)^autoconnect=", content):
          content = re.sub(
              r"(?m)^(\[connection\]\s*\n)", r"\1autoconnect=true\n", content, count=1
          )
      else:
          content = re.sub(r"(?m)^autoconnect=.*$", "autoconnect=true", content)
      if not re.search(r"^\[wifi-security\]", content, re.M):
          content = content.rstrip() + "\n[wifi-security]\nkey-mgmt=wpa-psk\n"
      content = re.sub(r"(?m)^psk-flags=.*$", "psk-flags=0", content)
      if re.search(r"(?m)^psk=", content):
          content = re.sub(r"(?m)^psk=.*$", lambda _m: f"psk={psk}", content)
      else:
          content = re.sub(
              r"(?m)^(\[wifi-security\]\s*\n)",
              lambda _m: f"[wifi-security]\nkey-mgmt=wpa-psk\npsk={psk}\n",
              content,
              count=1,
          )
          if not re.search(r"(?m)^psk=", content):
              content = content.rstrip() + f"\npsk={psk}\n"
      with open(path, "w", encoding="utf-8") as f:
          f.write(content)
      return 0


  if __name__ == "__main__":
      sys.exit(main())
''
