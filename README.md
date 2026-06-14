# Oracle Linux Security Patching

This project contains an OS-level patching approach for Oracle Linux 7, 8, and 9 systems that receive packages from ULN or enabled Oracle Linux repositories.

When your instance is run on Oracle OCI the recommended method is to use OS Managenet Hub. OS Managenet Hub is a agent running or your instance, with 
reporting back to to OCI Observability and Monitoring, designed for fleet management of OEL Instances. [OS Management hub documentation page](https://docs.oracle.com/en-us/iaas/oracle-linux/oci/security-os-mgmt-hub.htm)

The scripts are intended for Oracle Linux instances running in Oracle Cloud Infrastructure, but they do not depend on OCI APIs. They use the local package manager and the repositories already configured on the host.
[Manual Package Commands](#Manual-Package-Commands) The Manal Package Commands are great for one-off pathing. If you are in a hurry you may evaluate this option, commands are below for inspiration. 

The scripts and comments are for educational purpose only, to demonstrate features of Oracle Enteprise Linux. For security patching, make yor own risk assessment and 
requirement judgement.

(c) Inge Os 2026

## Contents

- `scripts/ol-security-patch.sh`: patch wrapper for Oracle Linux 7/8/9.
- `scripts/install.sh`: installs the script, config, and systemd units.
- `scripts/uninstall.sh`: removes the installed units and script.
- `config/ol-security-patching.conf`: default runtime configuration.
- `systemd/ol-security-patch.service`: one-shot patch service.
- `systemd/ol-security-patch.timer`: weekly patch schedule.
- `docs/runbook.md`: operational runbook.
- `LICENSE`: Apache 2.0 license terms for this project.

## Default Behavior

By default, the project:

1. Applies security-only updates.
2. Uses `yum` on Oracle Linux 7.
3. Uses `dnf` on Oracle Linux 8 and 9.
4. Logs to `/var/log/ol-security-patch.log`.
5. Uses a lock file to prevent overlapping runs.
6. Marks reboot-required state with `/var/run/reboot-required-by-security-patch`.
7. Does not reboot automatically.

## Manual Package Commands

Oracle Linux 7 security-only patching:

```bash
sudo yum updateinfo list security
sudo yum -y --security update-minimal
```

Oracle Linux 8/9 security-only patching:

```bash
sudo dnf updateinfo list --security
sudo dnf -y upgrade --security
```

All available updates instead of security-only:

```bash
sudo yum -y update
sudo dnf -y upgrade
```

## Install

From the project root:

```bash
sudo scripts/install.sh
```

The installer copies:

- `/usr/local/sbin/ol-security-patch.sh`
- `/etc/ol-security-patching.conf`
- `/etc/systemd/system/ol-security-patch.service`
- `/etc/systemd/system/ol-security-patch.timer`

It also enables the timer.

## Configure

Edit:

```text
/etc/ol-security-patching.conf
```

Common settings:

```bash
PATCH_MODE=security
REBOOT_POLICY=mark-only
```

Set `PATCH_MODE=all` to apply all available updates instead of security-only updates.

## Run Manually

```bash
sudo /usr/local/sbin/ol-security-patch.sh
```

Dry run:

```bash
sudo /usr/local/sbin/ol-security-patch.sh --dry-run
```

Force all updates for one run:

```bash
sudo /usr/local/sbin/ol-security-patch.sh --mode all
```

## Reboot Handling

The script runs `needs-restarting -r` when available.

If a reboot is required, it creates:

```text
/var/run/reboot-required-by-security-patch
```

The script does not reboot the server automatically. Rebooting should normally be handled by a maintenance workflow, especially for clustered or load-balanced applications.

Install reboot detection helpers:

```bash
sudo yum -y install yum-utils
sudo dnf -y install dnf-utils
```

Use the command that matches the OS major version.

## Uninstall

From the project root:

```bash
sudo scripts/uninstall.sh
```

The config file under `/etc/ol-security-patching.conf` is left in place unless you pass:

```bash
sudo scripts/uninstall.sh --purge-config
```

## Local Checks

```bash
make check
```

## License

This project is licensed under the Apache License 2.0. See `LICENSE` for the full license text.

## Notes

- Oracle Linux 7 uses `yum`.
- Oracle Linux 8 and 9 use `dnf`.
- The package commands use whatever ULN channels or repositories are enabled on the host.
- For production, patch dev/test first, then patch production in batches.
- For OCI-managed fleets, OCI OS Management Hub can be used for reporting, grouping, scheduling, and patch governance.
