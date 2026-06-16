%include continuous-integration/build/spec_common_variables.inc

%define nep_project_dir         nep
%define nep_project_doc_dir     %{nep_project_dir}/doc/

%define neteye_nep_dir          %{ne_dir}/nep/
%define nep_repository_dir      /neteye/shared/nep
%define nep_packages_dir        %{nep_repository_dir}/data/packages
%define nep_setup_bin           %{neteye_nep_dir}/setup/nep-setup
%define nep_setup_sbin_symlink     %{_sbindir}/nep-setup

%global new_services_structure %(test -f %{_sourcedir}/nep/setup/conf/nep.yaml && echo 1 || echo 0)

Name:    neteye-nep
Version: %{automatic_rpm_version}
Release: %{automatic_rpm_release}
Summary: neteye-nep Package
Requires: python39-toml

Group:	 Applications/System
License: GPL v3
Source0: %{name}.tar.gz
BuildArch: x86_64

AutoReqProv: no

%global debug_package %{nil}

%description
%{summary}

%prep
%setup -c

%build
%define new_services_structure %(test -f nep/setup/conf/nep.yaml && echo 1 || echo 0)


%install
mkdir -p %{buildroot}/%{neteye_nep_dir}
mkdir -p %{buildroot}/%{nep_repository_dir}
mkdir -p %{buildroot}/%{nep_packages_dir}
mkdir -p %{buildroot}/%{_sbindir}

# Update and upgrade
mkdir -p %{buildroot}/%{ne_parallel_update_upgrade_dir}/
cp -rpv src/update_upgrade/* %{buildroot}/%{ne_parallel_update_upgrade_dir}/

# Do not ship the directory /doc/ of the nep project. It is only used for the online userguide
rm -rf %{nep_project_doc_dir}
%if %{new_services_structure}
  mkdir -p %{buildroot}%{ne_services_dir}/contrib
  mv %{nep_project_dir}/setup/conf/nep.yaml %{buildroot}%{ne_services_dir}/contrib/
%endif

mv %{nep_project_dir}/* %{buildroot}/%{neteye_nep_dir}

# links nep-setup executable in useful places
ln -s %{nep_setup_bin} %{buildroot}/%{nep_setup_sbin_symlink}

%files
%{neteye_nep_dir}

%defattr(0640, root, root, 0755)
%{ne_parallel_update_upgrade_dir}/neteye-nep

%if %{new_services_structure}
%defattr(0644, root, root, 0755)
%config(noreplace) %{ne_services_dir}/contrib/nep.yaml
%endif

%attr(555, root, root) %{nep_setup_bin}
%{nep_repository_dir}
%{nep_setup_sbin_symlink}

%changelog
%{automatic_rpm_changelog}
- Latest build of %{name}
