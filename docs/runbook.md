# Oracle Linux Patching Runbook

## Scope

Use this runbook for Oracle Linux 7, 8, and 9 hosts that patch from ULN or enabled Oracle Linux repositories.

## Pre-Checks

1. Confirm the host is Oracle Linux:

   ```bash
   cat /etc/os-release
   ```

2. Confirm package repositories or ULN channels are available:

   ```bash
   yum repolist
   dnf repolist
   ```

   Use the command that matches the OS major version.

3. Confirm recent backup coverage before production patching.

4. Confirm application owners have approved the maintenance window.

## Dry Run

```bash
sudo /usr/local/sbin/ol-security-patch.sh --dry-run
```

## Apply Security Updates

```bash
sudo /usr/local/sbin/ol-security-patch.sh --mode security
```

## Apply All Updates

```bash
sudo /usr/local/sbin/ol-security-patch.sh --mode all
```

## Check Scheduled Timer

```bash
systemctl status ol-security-patch.timer
systemctl list-timers ol-security-patch.timer
```

## Check Logs

```bash
sudo tail -200 /var/log/ol-security-patch.log
```

## Reboot Check

```bash
test -f /var/run/reboot-required-by-security-patch && echo "reboot required"
```

When available:

```bash
sudo needs-restarting -r
```

## Rollout Guidance

1. Patch one development host first.
2. Patch test or staging hosts next.
3. Patch production in batches.
4. Reboot one node at a time for clustered or load-balanced services.
5. Confirm application health after each batch.

## Failure Handling

1. Review `/var/log/ol-security-patch.log`.
2. Check repository or ULN reachability.
3. Retry with `--dry-run` to inspect the transaction.
4. If packages were partially updated, complete the package transaction before rebooting.
5. Restore from backup only if the package transaction or application validation cannot be recovered safely.
