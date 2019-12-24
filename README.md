# Virtual Host

Simple bash script file for Apache and Nginx to create, rename, delete or changing document directory for virtual hosts on Ubuntu.

## Installation

```bash
Apache
-------
wget -O vhost https://raw.githubusercontent.com/mmabdelgawad/virtualhost/master/vhost-apache.sh
chmod +x vhost

Nginx
-----
wget -O vhost https://raw.githubusercontent.com/mmabdelgawad/virtualhost/master/vhost-nginx.sh
chmod +x vhost
```

#### Run the script globally
```bash
cd /usr/local/bin/

Apache
------
wget -O vhost https://raw.githubusercontent.com/mmabdelgawad/virtualhost/master/vhost-apache.sh
chmod +x vhost

Nginx
-----
wget -O vhost https://raw.githubusercontent.com/mmabdelgawad/virtualhost/master/vhost-nginx.sh
chmod +x vhost
```

## Usage

* Creating new virtual host
```bash
sudo bash vhost create [domain] [hosting directory]
```

```bash
sudo bash vhost create vhost.local /var/www/html/my-website
```

> Note that while creating new virtual host you need to provide the full path of the website directory like
>   * /var/www/html/my-website
>   * /var/www/my-website
> 
> if the folder does not exist it be will created automatically
---
* Renaming existing virtual host
```bash
sudo bash vhost rename [domain] [new domain name]
```

```bash
sudo bash vhost rename vhost.local my-website.local
```
---
* Deleting existing virtual host
```bash
sudo bash vhost delete [domain] [optional - hosting directory]
```

```bash
sudo bash vhost delete vhost.local /var/www/html/my-website
```
> Note that deleting the hosting directory will delete it **recursively**
---
* Change virtual host document root directory
```bash
sudo bash vhost change [domain] [new hosting directory]
```

```bash
sudo bash vhost change vhost.local /var/www/html/my-new-website
```