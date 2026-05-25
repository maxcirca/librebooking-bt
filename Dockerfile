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
RUN sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80>/:8080>/' /etc/apache2/sites-enabled/000-default.conf \
    && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/Web|' \
        /etc/apache2/sites-enabled/000-default.conf \
    && a2dismod mpm_event mpm_worker || true \
    && a2enmod mpm_prefork rewrite headers

# Allow .htaccess overrides
RUN echo '<Directory /var/www/html/Web>\n\
    Options -Indexes +FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' >> /etc/apache2/sites-enabled/000-default.conf

# Copy application
COPY --chown=www-data:www-data . /var/www/html/

WORKDIR /var/www/html

# Install Composer dependencies
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --optimize-autoloader \
    --no-scripts \
    --no-interaction

# Ensure writable directories
RUN mkdir -p tpl_c uploads/images uploads/tos \
    && chown -R www-data:www-data tpl_c uploads

EXPOSE 8080

CMD ["apache2-foreground"]
