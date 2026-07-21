# Build a release version of rde-wifi
cargo build --release --package rde-wifi

# Show installing..
echo "Installing..."

# Install the rde-wifi binary with read, write and execute permissions
sudo install -Dm755 target/release/rde-wifi /usr/bin/rde-wifi

# Install the systemd user service with read and write permissions
sudo install -Dm644 assets/systemd/rde-wifi.service /usr/lib/systemd/user/rde-wifi.service

# Install the polkit rules with read and write permissions
sudo install -Dm644 assets/polkit/org.rde.wifi.rules /etc/polkit-1/rules.d/10-org.rde.wifi.rules

# Show finished
echo "Done!"
