FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf

# Create certbot webroot for ACME challenges
RUN mkdir -p /var/www/certbot

EXPOSE 80 443