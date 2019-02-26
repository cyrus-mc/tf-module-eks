#cloud-config

write_files:
- path: /etc/nginx/tcpconf.d/eks.conf
  mode: '0640'
  content: |
    stream {
        upstream eks {
          server ${EKS_ENDPOINT}:443;
        }

      server {
        listen 443;
        proxy_pass eks;
      }
    }

runcmd:
 - [ sh, -c, "amazon-linux-extras install -y nginx1.12" ]
 - [ sh, -c, "echo 'include /etc/nginx/tcpconf.d/*.conf;' >> /etc/nginx/nginx.conf" ]
 - systemctl enable nginx
 - systemctl start nginx
