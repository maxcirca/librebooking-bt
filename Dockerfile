FROM php:8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libldap-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd \
        ldap \
        mysqli \
        pdo_mysql \
        opcache

# Install Composer
COPY --from=composer:lts /usr/bin/composer /usr/bin/composer

# Configure Apache: listen on 8080, serve from Web/
# Forcefully remove any conflicting MPM symlinks, then enable only mpm_prefork
RUN sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80>/:8080>/' /etc/apache2/sites-enabled/000-default.conf \
    && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/Web|' \
        /etc/apache2/sites-enabled/000-default.conf \
    && rm -f /etc/apache2/mods-enabled/mpm_event.load \
              /etc/apache2/mods-enabled/mpm_event.conf \
              /etc/apache2/mods-enabled/mpm_worker.load \
              /etc/apache2/mods-enabled/mpm_worker.conf \
    && a2enmod mpm_prefork rewrite headers \
    && echo 'ServerName localhost' >> /etc/apache2/apache2.conf

# Configure the docroot:
#   - Allow .htaccess overrides for app-level rules
#   - Trust Railway's edge X-Forwarded-Proto so PHP sees HTTPS=on and any
#     SSL-aware code paths behave correctly behind the TLS-terminating proxy
RUN echo '<Directory /var/www/html/Web>\n\
    Options -Indexes +FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
    DirectoryIndex index.php index.html\n\
    SetEnvIf X-Forwarded-Proto "https" HTTPS=on\n\
</Directory>' >> /etc/apache2/sites-enabled/000-default.conf

# Copy application
COPY --chown=www-data:www-data . /var/www/html/

# The repo's root .htaccess redirects non-/Web URLs to /Web/* — that was for
# upstream's docroot=/var/www/html layout. We serve directly from Web/, so it
# would cause a /Web/Web/ redirect loop. Remove it post-copy.
RUN rm -f /var/www/html/.htaccess

WORKDIR /var/www/html

# Install Composer dependencies
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --optimize-autoloader \
    --no-scripts \
    --no-interaction

# Ensure writable directories
RUN mkdir -p tpl_c uploads/images uploads/tos \
    && chown -R www-data:www-data tpl_c uploads

# Entrypoint: fix MPM at runtime too (belt-and-suspenders) then start Apache
RUN chmod +x /var/www/html/docker-entrypoint.sh
EXPOSE 8080
CMD ["/var/www/html/docker-entrypoint.sh"]
