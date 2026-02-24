FROM christianbangoy2017/ihomis-app:php7.4

# Install GD for TCPDF PNG alpha support
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html
