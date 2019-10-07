# Virtual Host

Simple bash script file to create, rename or delete Apache virtual hosts on Ubuntu.

## Installation

```bash
wget -O vhost-apache https://raw.githubusercontent.com/mmabdelgawad/virtualhost/master/vhost-apache.sh

chmod +x vhost-apache
```

#### Run the script globally
```bash
cd /usr/local/bin/

wget -O vhost-apache https://raw.githubusercontent.com/mmabdelgawad/virtualhost/master/vhost-apache.sh

chmod +x vhost-apache
```

## Usage

* Creating new virtual host
```bash
sudo bash vhost-apache create [domain] [hosting directory]
```

```bash
sudo bash vhost-apache create vhost.local /var/www/html/my-website
```

> Note that while creating new virtual host you need to provide the full path of the website directory like
>   * /var/www/html/my-website
>   * /var/www/my-website
> 
> if the folder does not exist it be created automatically
---
* Renaming existing virtual host
```bash
sudo bash vhost-apache rename [domain] [new domain name]
```

```bash
sudo bash vhost-apache rename vhost.local my-website.local
```
---
* Deleting existing virtual host
```bash
sudo bash vhost-apache delete [domain] [optional - hosting directory]
```

```bash
sudo bash vhost-apache delete vhost.local /var/www/html/my-website
```
> Note that deleting the hosting directory will delete it **recursively**
