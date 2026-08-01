# website deployment

Static site (`website/` at repo root — plain HTML/CSS, no build step,
same convention as `web-wallet/` and `explorer/`) deployed to a
general-purpose VPS shared with other unrelated projects, at
`/var/www/codexacoin.com`.

## Deploying

```bash
rsync -az website/ root@<vps>:/var/www/codexacoin.com/
ssh root@<vps> "chown -R www-data:www-data /var/www/codexacoin.com"
```

## nginx + TLS

`nginx-codexacoin.com.conf` in this directory is a copy of the live,
certbot-managed config (`/etc/nginx/sites-available/codexacoin.com` on
the VPS) — pulled back here for reference/reproducibility, not applied
by any script. To recreate on a fresh box:

```bash
cp nginx-codexacoin.com.conf /etc/nginx/sites-available/codexacoin.com
ln -s /etc/nginx/sites-available/codexacoin.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
certbot --nginx -d codexacoin.com -d www.codexacoin.com --redirect
```

Cert renewal is handled by certbot's own systemd timer (already active
on this box for its other sites); nothing CodexaCoin-specific to
maintain there.

## Verified (2026-08-01)

`https://codexacoin.com` and `https://www.codexacoin.com` both serve
the real site with a valid Let's Encrypt cert (expires 2026-10-30,
auto-renews); plain `http://` correctly redirects to `https://`.
