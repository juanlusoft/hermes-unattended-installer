# Hermes OAuth flow

This installer supports a guided Hermes OAuth setup for `openai-codex`.

## What it does

- Installs Hermes and Ollama if needed.
- Starts the Hermes auth flow for the selected provider.
- Runs the auth command in an interactive TTY so Hermes can print the browser link or device code.
- Lets you finish the login in your browser and paste any required code back into the terminal.
- Verifies the resulting auth state with `hermes auth status`.

## Supported flags

```bash
--hermes-auth-provider openai-codex
--hermes-auth-type oauth
--hermes-auth-no-browser
--hermes-auth-browser
--skip-hermes-auth
```

## Recommended usage

```bash
curl -fsSL https://raw.githubusercontent.com/juanlusoft/hermes-unattended-installer/main/install-hermes-unattended.sh | bash -s -- \
  --hermes-auth-provider openai-codex \
  --hermes-auth-type oauth \
  --hermes-auth-no-browser
```

## Notes

- The flow is intentionally interactive at the auth step.
- If Hermes emits a link, open it in a browser and complete the login.
- If Hermes emits a code, paste it back into the terminal.
- This is the Hermes provider flow, not the OpenAI API-key flow.
