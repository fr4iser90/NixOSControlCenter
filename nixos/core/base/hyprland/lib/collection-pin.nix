# Pin for https://github.com/fr4iser90/NCC-Hyperland-Collection
# Update after pushing collection changes:
#   nix-build -E 'with import <nixpkgs> {}; fetchFromGitHub {
#     owner="fr4iser90"; repo="NCC-Hyperland-Collection"; rev="<sha>";
#     hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; }'
#   → use the "got:" hash from the mismatch error
{
  owner = "fr4iser90";
  repo = "NCC-Hyperland-Collection";
  rev = "687f1fd";
  hash = "sha256-uGerU9DP/ApuL+1v3M1SBRywzSO3CsuQDf0ZCwL8o+k=";
}
