# Hermes unattended installer

```bash
curl -fsSL https://raw.githubusercontent.com/juanlusoft/hermes-unattended-installer/main/install-hermes-unattended.sh | bash
```

## Flujo guiado de OAuth de Hermes

Para activar la configuración guiada de OAuth para `openai-codex`:

```bash
curl -fsSL https://raw.githubusercontent.com/juanlusoft/hermes-unattended-installer/main/install-hermes-unattended.sh | bash -s -- \
  --hermes-auth-provider openai-codex \
  --hermes-auth-type oauth \
  --hermes-auth-no-browser
```

El instalador mostrará el enlace o código de autorización si Hermes lo genera y mantendrá la terminal interactiva para terminar el login.

Detalles completos: [HERMES_OAUTH.md](./HERMES_OAUTH.md)

## Guided Hermes OAuth flow

To enable the browser-based OAuth setup for `openai-codex`:

```bash
curl -fsSL https://raw.githubusercontent.com/juanlusoft/hermes-unattended-installer/main/install-hermes-unattended.sh | bash -s -- \
  --hermes-auth-provider openai-codex \
  --hermes-auth-type oauth \
  --hermes-auth-no-browser
```

The installer will print the authorization link or code if Hermes emits one, then keep the terminal interactive so you can finish login.
