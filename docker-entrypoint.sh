#!/bin/sh
# Ensure only mpm_prefork is active (prevents 'More than one MPM loaded' crash)
rm -f /etc/apache2/mods-enabled/mpm_event.load \
      /etc/apache2/mods-enabled/mpm_event.conf \
      /etc/apache2/mods-enabled/mpm_worker.load \
      /etc/apache2/mods-enabled/mpm_worker.conf
# Make sure mpm_prefork symlinks exist
ln -sf /etc/apache2/mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load 2>/dev/null || true
ln -sf /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf 2>/dev/null || true

# Build-time `rm -f` of these has been observed to not take effect (Railway
# layer caching / overlay weirdness). Repeat the removal at startup so the
# running container always has a clean slate.
rm -f /etc/apache2/sites-enabled/000-default.conf
rm -f /var/www/html/.htaccess

# Diagnostic: dump active vhost config + .htaccess inventory so misbehaviour
# (e.g. unexpected redirects) can be diagnosed from Railway logs alone.
echo "===== apache sites-enabled ====="
ls -la /etc/apache2/sites-enabled/ || true
for f in /etc/apache2/sites-enabled/*; do
    echo "----- $f -----"
    cat "$f" || true
done
echo "===== .htaccess files under /var/www/html ====="
find /var/www/html -maxdepth 3 -name '.htaccess' 2>/dev/null || true
echo "===== apache2ctl -S ====="
apache2ctl -S 2>&1 || true
echo "===== /var/www/html/Web listing ====="
ls -la /var/www/html/Web/ 2>/dev/null | head -20 || true

exec apache2-foreground
