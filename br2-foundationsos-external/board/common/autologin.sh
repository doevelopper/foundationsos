#!/bin/sh

# Comment out default login prompt
# sed -e '/tty1/s/^/#/g' -i output/target/etc/inittab

# Change login prompt to use autologin below
# sed '/#tty1/a tty1\:\:respawn\:\/sbin\/getty \-L \-n \-l /usr/sbin/autologin tty1 0 vt100' -i output/target/etc/inittab

# Write an autologin script
cat << 'EOF' >> output/target/usr/sbin/autologin
#!/bin/sh
exec login -f aulos
EOF

# Make it executable
chmod +x output/target/usr/sbin/autologin
