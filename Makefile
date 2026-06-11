.PHONY: check

check:
	bash -n scripts/ol-security-patch.sh
	bash -n scripts/install.sh
	bash -n scripts/uninstall.sh
