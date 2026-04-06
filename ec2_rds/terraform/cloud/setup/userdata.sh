#!/bin/bash

# Actualiza los paquetes e instala las dependencias necesarias
sudo apt-get update && sudo apt-get install -y python3-pip python3-dev libpq-dev nginx curl
sudo apt-get install -y postgresql postgresql-contrib

# Instalación de Pipenv
sudo pip3 install pipenv

# Configura las claves SSH para GitHub
echo "${ssh_private_key}" > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
ssh-keyscan github.com >> /root/.ssh/known_hosts

# Setup para directorio del proyecto
mkdir /home/ubuntu/django-cms
cd /home/ubuntu/django-cms

# Copia el proyecto desde tu repositorio o ubicación de almacenamiento
git clone git@github.com:vteran93/growthguard.io.git .

# Instala las dependencias del proyecto usando Pipenv
pipenv install --deploy --ignore-pipfile

# Configura variables de entorno necesarias
export DJANGO_SETTINGS_MODULE="growthguard.settings.defaults"
export SECRET_KEY="${django_secret_key}"
export DEBUG="False"

export DATABASE_DB_NAME="${database_db_name}"
export DATABASE_DB_USER="${database_db_user}"
export DATABASE_DB_PASSWORD="${database_db_password}"
export DATABASE_ADDRESS="${database_address}"
export DATABASE_PORT="${database_port}"

export AWS_STORAGE_BUCKET_NAME=${aws_storage_bucket_name}

# Aplica migraciones y recoge archivos estáticos
pipexec(){
  pipenv run "$@"
}
pipexec python manage.py migrate
pipexec python manage.py collectstatic --no-input

# Configura Gunicorn con Nginx
pipexec pip install gunicorn
sudo tee /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/django-cms
ExecStart=/home/ubuntu/.local/bin/pipenv run gunicorn --workers 3 --bind unix:/home/ubuntu/django-cms/django-cms.sock growthguard.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start gunicorn
sudo systemctl enable gunicorn

# Configuración de Nginx para servir el proyecto
sudo rm /etc/nginx/sites-enabled/default
sudo tee /etc/nginx/sites-available/django-cms <<EOF
server {
    listen 80;
    server_name ${project};

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        alias /home/ubuntu/django-cms/staticfiles/;
    }
    location / {
        include proxy_params;
        proxy_pass http://unix:/home/ubuntu/django-cms/django-cms.sock;
    }
}
EOF
sudo ln -s /etc/nginx/sites-available/django-cms /etc/nginx/sites-enabled
sudo systemctl restart nginx
