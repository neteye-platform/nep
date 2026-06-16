#Common variables in spec files

#NetEye directories
%define ne_local_dir            /neteye/local/
%define ne_shared_dir           /neteye/shared/
%define ne_script_dir           %{ne_dir}/scripts/
%define ne_dir                  %{_datadir}/neteye/
%define ne_ug_dir               %{ne_dir}/userguide/
%define ne_secure_install_dir   %{ne_dir}/secure_install/
%define ne_secure_install_es_only_dir    %{ne_dir}/secure_install_elastic_only/
%define ne_secure_install_voting_only_dir %{ne_dir}/secure_install_voting_only/
%define ne_secure_install_satellites_dir %{ne_dir}/secure_install_satellite/
%define ne_secure_install_tenant_dir     %{ne_dir}/secure_install_tenant/
%define ne_local_checks_dir     %{ne_dir}/local_checks/
%define wwwconfigdir            %{_sysconfdir}/httpd/conf.d
%define phpconfigdir            %{ne_local_dir}/php/conf/php.d/
%define phpfpmconfigdir         %{ne_local_dir}/php/conf/php-fpm.d/
%define icingaweb_modules_dir   %{_datadir}/icingaweb2/modules/
%define icingaweb_modules_conf_dir   %{ne_shared_dir}/icingaweb2/conf/modules/
%define packages_d		%{ne_script_dir}/packages_structure/packages.d/
%define playwright_tests_dir %{ne_dir}/test/playwright/tests
%define playwright_users_dir %{ne_dir}/test/playwright/users
%define upgrade_update_configurator_procedures_dir /usr/share/neteye/scripts/upgrade/module_upgrade_procedures
%define ansible_root_collections_dir	/root/.ansible/collections/ansible_collections/
%define ansible_collections_ansible_dir	%{ansible_root_collections_dir}ansible/
%define ansible_collections_community_dir	%{ansible_root_collections_dir}community/
%define ansible_collections_neteye_dir	%{ansible_root_collections_dir}neteye/
%define ne_install_dir          %{ne_dir}/install/
%define ne_parallel_install_dir          %{ne_dir}install/
%define ne_parallel_update_upgrade_dir %{ne_dir}update_upgrade/
%define ne_satellite_parallel_update_upgrade_dir %{ne_dir}satellite_update_upgrade/
%define ne_cluster_conf_validators_dir  %{ne_dir}cluster/config_validators/
%define ne_cluster_conf_validators_roles_dir  %{ne_cluster_conf_validators_dir}roles.d/
%define ne_services_dir        /etc/neteye-services.d/
%define ne_services_dir_templates        /usr/share/neteye/neteye-services.d-templates/
%define backup_conf_dir                     /etc/neteye-backup.d/
%define backup_templates_dir                %{ne_dir}/backup-templates
%define backup_parallel_config_apply_dir    %{ne_dir}/backup-config-apply
%define backup_parallel_run_dir             %{ne_dir}/backup-run
%define backup_parallel_restore_dir         %{ne_dir}/backup-restore

# SOS reports variables
%define sosreport_plugins_dir /usr/lib/python3.6/site-packages/sos/report/plugins/

# Ansible requirements
%define ansible_lower_than_version 2.14
%define require_ansible_core Requires: ansible-core < %{ansible_lower_than_version}
%define require_ansible_test Requires: ansible-test < %{ansible_lower_than_version}

#NetEye test directories
%define testdir %{ne_dir}/test/%{name}
#   When testing the mirror setup we want to use a separate testdir otherwise the neteye test runner will run
#   all the tests including the mirror-related ones that will fail if a mirror is not set.
#   The test placed in the standard folder have to run independently from the mirror-related ones
#   To run the mirror-related tests we will need to setup a mirror first
%define rpm_integration_testdir %{ne_dir}/test/rpm_mirror/%{name}
%define parallel_testdir %{ne_dir}/test-parallel/

# Health checks dirs
%define healthcheck_base_dir	%{ne_dir}/scripts/neteye/health.d/
%define healthcheck_light_dir	%{healthcheck_base_dir}/light/
%define healthcheck_deep_dir	%{healthcheck_base_dir}/deep/

%define upgrade_prerequisite_checks_dir %{ne_script_dir}/upgrade/upgrade-prerequisite-checks/
%define update_prerequisite_checks_dir %{ne_script_dir}/upgrade/update-prerequisite-checks/

# documentation (md) dirs
%define iw2_doc_dir %{_datadir}/icingaweb2/doc/

%define systemd_dir             %{_prefix}/lib/systemd/system/
%define systemd_plugin_dir      %{_sysconfdir}/systemd/system/
# Do not use this! this is deprecated, and identical to ne_dir
%define ne_usr_share_dir         /usr/share/neteye/
# directory where we install all the *.conf.tpl files for cluster services installation
%define ne_cluster_templates_dir %{ne_dir}/cluster/templates

#Internal URLs
%define wp_mirror            http://developers.wuerth-phoenix.com/static/downloads

%define neteye_version          %(grep -o -E '[0-9]+\.[0-9]+' /etc/neteye-release)

# Automatic RPM versioning [neteye_version + timestamp], and changelog
# Escape percent symbol as described here: http://rpm.org/user_doc/macros.html
%define today                   %(date -u +'%%Y%%m%%d')
%define time                    %(date -u +'%%H%%M%%S')
%define automatic_rpm_version       %{neteye_version}.%{today}
%define automatic_rpm_release       %{time}
%define automatic_rpm_changelog     * %(date +'%%a %%b %%d %%Y') SI Development <si.development@wuerth-phoenix.com> - %{version}-%{release}

%define run_php_unit_path       /usr/bin/run_php_unit

%define package_userguide %%package userguide\
Summary: Userguide files for %{name}\
%%description userguide\
Userguide files for %{name} in .rst format\
%%files userguide\
%%defattr(-,root,root,-)\
%{ne_ug_dir}

#User guide
%define install_userguide %{__mkdir_p} %{buildroot}/%{ne_ug_dir}/source \
%{__mkdir_p} %{buildroot}/%{ne_ug_dir}/source-originals/glossary \
if [ -f doc/glossary/* ]; then \
mv doc/glossary/* %{buildroot}/%{ne_ug_dir}/source-originals/glossary \
fi \
cp -r doc/* %{buildroot}/%{ne_ug_dir}/source/

# rust build
# --define 'debugbuild 1' will trigger a rustc debug build, not release
%define cargo_build_target_dir target/release/
%if 0%{?debugbuild:1}
%define cargo_build_target_dir target/debug/
%endif

%define cargo_build %if 0%{?debugbuild:1} \
cargo build \
%else \
cargo build --release \
%endif