# home_lab

Pi-hole + Samba + Netdata running in Docker on a Raspberry Pi 4 (`pegasus.local`), provisioned via Ansible.

## Architecture

- 1 Raspberry Pi 4 (8GB), hostname `pegasus.local`.
- Storage at `/mnt/storage`, mounted by **LABEL** (`storage`), not by device path — lets you swap the physical media (pendrive today, SSD via Argon ONE M.2 later) without changing any config.
- 3 Docker containers: `pihole`, `samba` (`ghcr.io/servercontainers/samba`), `netdata`.

## Prerequisites

**Control machine (where you run Ansible):**
- Python 3 and `ansible` installed
- `make install-collections` (installs `community.docker` and `ansible.posix`)

**On the Pi:**
- Raspberry Pi OS already flashed, SSH enabled, user with sudo
- Working network connectivity (see "Step 0" below)

## Step 0 — connectivity pre-flight

Before anything else, confirm the Pi is reachable by name:

```bash
getent hosts pegasus.local   # or: ping -c1 pegasus.local
```

If it fails:

- **(a) Recommended** — install mDNS support on this control machine:
  ```bash
  sudo apt install -y avahi-daemon libnss-mdns
  sudo systemctl enable --now avahi-daemon
  ```
  Confirm `/etc/nsswitch.conf` has `mdns4_minimal` (or `mdns4`) on the `hosts:` line — the package usually adds this on its own. Retest with `getent hosts pegasus.local`.
- **(b) Fallback** — if `.local` still doesn't resolve, grab the Pi's current IP from your router's client list, or by an ARP scan filtered by Raspberry Pi Foundation MAC prefixes (`b8:27:eb`, `dc:a6:32`, `e4:5f:01`, `28:cd:c1`), and point Ansible at the IP directly:
  ```bash
  ansible-playbook -i "192.168.x.x," -u gobbi ansible/site.yml
  ```
  (the trailing comma is required to indicate a single-host list)

Also do a plain SSH test before running Ansible, to separate "name doesn't resolve" from "SSH/auth doesn't work":
```bash
ssh gobbi@pegasus.local echo ok
```

## Manual step — prepare the storage (once, on the Pi itself)

**This is deliberately not automated by Ansible** — formatting the wrong disk is destructive and irreversible, so this step stays manual and explicit.

Connect the pendrive to the Pi and, over SSH (`ssh gobbi@pegasus.local`):

```bash
lsblk                                   # identify the right device, e.g. /dev/sda1
sudo mkfs.ext4 -L storage /dev/sda1     # double-check the device before running this!
```

The Ansible `storage` role assumes this label already exists and will fail with a clear error if it doesn't — that's intentional.

When migrating to the SSD (Argon ONE M.2) later: format the new disk with the **same label** `storage`, copy the data over (`rsync -aHAX`), swap the hardware — no config changes needed.

## Quick start

```bash
cp docker/.env.example docker/.env
# edit docker/.env with real passwords

make install-collections
make ping        # confirms SSH/auth/Python before touching any config
make check        # dry-run (--check --diff)
make deploy        # runs for real
```
## Wi-Fi

Wi-Fi is set up when you flash the Pi (Raspberry Pi Imager, see below), not by Ansible: Ansible needs the network to reach the Pi in the first place.

**5 GHz caveat:** the Pi 4's Wi-Fi firmware keeps **channels 144–165 disabled**, even with the country set to BR. A 5 GHz network on channel 149–165 is invisible to the Pi. Use a 2.4 GHz network, or a 5 GHz one on channel 36–48.

## Reflashing the Pi from scratch

1. **Flash with Raspberry Pi Imager** and open its OS customisation settings:
   - hostname `pegasus`, user `gobbi`, enable SSH (public-key auth with your key is best)
   - Wi-Fi: SSID `<ssid>` (2.4 GHz, see the caveat above) and password, Wi-Fi country **BR**
2. **Boot and check it's reachable.** The SSH host key has changed, so clear the old one first:
   ```bash
   ssh-keygen -R pegasus.local
   ssh gobbi@pegasus.local echo ok
   ```
3. **Storage:** if the pendrive/SSD is the same one, **don't reformat it**. It already has the `storage` label and your data.
4. **Deploy:** `make ping && make deploy`.
5. **Router:** the DHCP reservation is tied to the Wi-Fi MAC.

## Manual post-deploy steps (out of Ansible's scope)

**Pi-hole**: log in at `http://pegasus.local/admin` (password = `PIHOLE_ADMIN_PASSWORD`) to review blocklists and the whitelist.

**Samba — how to access the `data` share**:
- Windows: `\\pegasus.local\data` in File Explorer (use the IP directly if `.local` doesn't resolve — Windows sometimes needs Bonjour installed)
- Linux: `smb://pegasus.local/data` in your file manager, or `mount -t cifs //pegasus.local/data <mountpoint> -o username=<SAMBA_USER>`
- Authenticate with `SAMBA_USER`/`SAMBA_PASSWORD` — this is an SMB-protocol auth account, independent of the system's Linux users.

**Netdata**: `http://pegasus.local:19999`.
