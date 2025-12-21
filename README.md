# sub0.productions

Website for Sub0 Productions

## Nix Apps / Packages

### Format

```bash
nix fmt
```

### Run development server

```bash
nix run
```

### Build site

```bash
nix build
```

### Deploy to Cloudflare Pages

Make sure to set `CLOUDFLARE_PROJECT_NAME`, `CLOUDFLARE_ACCOUNT_ID`, and `CLOUDFLARE_API_TOKEN` environment variables.

```bash
nix run .#deploy
```
