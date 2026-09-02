#cloud-config
package_update: true
package_upgrade: false

packages:
  - apache2
  - php
  - php-mysql
  - php-xml
  - php-curl
  - php-gd
  - php-mbstring
  - php-zip
  - cifs-utils
  - fuse3
  # NAPOMENA: blobfuse2 NIJE u standardnim Ubuntu apt repozitorijima, pa ga
  # ovdje ne stavljamo u "packages" (to je pucalo - PackageInstallerError).
  # Instalira se u runcmd nakon dodavanja Microsoftovog apt repozitorija.

write_files:
  # ── Blob (objektna pohrana) - montiran preko blobfuse2 s Managed Identity ──
  # Nema tajni na disku: autentikacija ide preko System Assigned MSI VM-a,
  # koji ima ulogu "Storage Blob Data Contributor" na storage accountu
  # (vidi iam.tf -> azurerm_role_assignment.app_blob_data_contributor).
  - path: /etc/blobfuse2/moodle-objects.yaml
    permissions: '0600'
    content: |
      logging:
        type: syslog
        level: log_warning
      components:
        - libfuse
        - file_cache
        - attr_cache
        - azstorage
      libfuse:
        attribute-expiration-sec: 120
        entry-expiration-sec: 120
      file_cache:
        path: /mnt/blobfusetmp/${instance_name}
        timeout-sec: 120
      azstorage:
        type: block
        account-name: ${storage_account_name}
        container: ${blob_container_name}
        endpoint: https://${storage_account_name}.blob.${azure_storage_dns_suffix}
        mode: msi

  # ── File Share (backupi) - montiran preko SMB sa storage account ključem ──
  # Azure Files SMB (mount -t cifs) NE podržava SAS token kao lozinku - to
  # je Azure protokol ograničenje (SAS radi samo za REST/API pristup, npr.
  # azcopy, ne i za mount.cifs basic auth). Jedine podržane opcije su storage
  # account ključ ili Azure AD Kerberos (zahtijeva domain join). Least-
  # privilege je ovdje osiguran time što je ključ vezan za storage account
  # SAMO tog developera (nije dijeljen), i čuva se s 0600 dozvolama.
  - path: /etc/smbcredentials/${instance_name}.cred
    permissions: '0600'
    content: |
      username=${storage_account_name}
      password=${storage_account_key}

  # systemd unit za blobfuse2 (preživljava reboot, za razliku od jednokratnog
  # runcmd mounta), pokreće se nakon network-online.target
  - path: /etc/systemd/system/blobfuse2-moodle.service
    permissions: '0644'
    content: |
      [Unit]
      Description=blobfuse2 mount za moodle-objects (MSI auth)
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=forking
      ExecStart=/usr/bin/blobfuse2 mount /mnt/moodle-objects --config-file=/etc/blobfuse2/moodle-objects.yaml
      ExecStop=/usr/bin/blobfuse2 unmount /mnt/moodle-objects
      Restart=on-failure

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Dodaj Microsoftov apt repo pa instaliraj blobfuse2 (nije u Ubuntu repou)
  - curl -sSL -o /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
  - dpkg -i /tmp/packages-microsoft-prod.deb
  - rm -f /tmp/packages-microsoft-prod.deb
  - apt-get update
  - apt-get install -y blobfuse2
  - mkdir -p /mnt/blobfusetmp/${instance_name}
  - mkdir -p /mnt/moodle-objects
  - mkdir -p /mnt/moodle-backups
  - chown -R www-data:www-data /mnt/moodle-objects /mnt/moodle-backups
  # File share mount preko storage account ključa (SMB ne podržava SAS), trajno u fstab-u
  - >
    echo "//${storage_account_name}.file.${azure_storage_dns_suffix}/${file_share_name}
    /mnt/moodle-backups cifs credentials=/etc/smbcredentials/${instance_name}.cred,serverino,nosharesock,mfsymlinks,vers=3.0,_netdev 0 0" >> /etc/fstab
  - mount /mnt/moodle-backups
  # Blob mount preko systemd servisa (MSI auth, auto-remount kod reboota)
  - systemctl daemon-reload
  - systemctl enable --now blobfuse2-moodle.service
  - systemctl enable apache2
  - systemctl restart apache2
