# 0.1.8
- NEP-527 fixed ITOA dashboards import for real this time

# 0.1.7
- NEP-777 Allow reinstall of all packages, regardless of their state
- NEP-775 Now nep-setup doesn't use ssh to run scripts on Satellites and SingleNodes, but does on the cluster master.
- NEP-779 The script args (NodeType, Tenant, Zone) now are fixed for satellite
- NEP-776 Now scripts are executed in parallel on all the cluster nodes
- Added quotes to `Executing` lines so we can try them manually when they fail
- Added `neteye` as implicit `enabled-modules` for `satellites`

# 0.1.6
- NEP-773 Provide current version when installing a new nep
- Updates to script templates

# 0.1.5
- Fix error NEP-772 where pre and post install scripts were not run on the master node
- Added `neteye_deployment` argument for pre and post install scripts

# 0.1.4
- Fix error in running chmod on pre-setup scripts that breaks all updates and installs!

# 0.1.3
- Fix NEP-527, the nep-setup didn't look in the correct folder to import ITOA dashboards
- NEP-760: Fix nep setup assumes all /neteye/shared/ subfolder are on mounted on the master node

# 0.1.2
- Added support for neteye modules aliases, in particular now "neteye-siem" == "neteye-elastic-stack"

# 0.1.1
- Added support for satellites
