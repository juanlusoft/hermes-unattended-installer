# Hermes unattended installer

```bash
curl -fsSL https://raw.githubusercontent.com/juanlusoft/hermes-unattended-installer/main/install-hermes-unattended.sh | bash
```

## Guided Hermes OAuth flow

To enable the browser-based OAuth setup for `openai-codex`:

```bash
curl -fsSL https://raw.githubusercontent.com/juanlusoft/hermes-unattended-installer/main/install-hermes-unattended.sh | bash -s -- \
  --hermes-auth-provider openai-codex \
  --hermes-auth-type oauth \
  --hermes-auth-no-browser
```

The installer will print the authorization link or code if Hermes emits one, then keep the terminal interactive so you can finish login.

Full details: [HERMES_OAUTH.md](./HERMES_OAUTH.md)
