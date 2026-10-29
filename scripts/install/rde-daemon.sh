# Build a release version of rde-brightness and rde-brightness-helper
cargo build --release --package rde-daemon

# Show installing..
echo "Installing..."

# Install The rde-brightness and rde-brightness-helper with read, write and execute permissions
sudo install -Dm755 target/release/rde-daemon /usr/bin/rde-daemon

sudo install -Dm644 assets/systemd/rde-daemon.service /usr/lib/systemd/user/rde-daemon.service

systemctl  --user daemon-reload

systemctl --user enable rde-daemon.service

# Show finished
echo "Done!"
