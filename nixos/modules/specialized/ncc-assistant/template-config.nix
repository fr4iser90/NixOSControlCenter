{
  enable = false;
  # OpenAI-compatible gateway (Ollama, llama.cpp, OpenWebUI, …)
  endpoint = "http://localhost:11434/v1";
  # Auth: leave unset — `ncc ai` prompts + caches in ~/.config/ncc-assistant/
  # apiKeyFile / apiHeaderName only for declarative secrets (sops) if you want.
  allowWrite = true;
  mcpAllowWrite = false;
  allowRebuild = false;
}
