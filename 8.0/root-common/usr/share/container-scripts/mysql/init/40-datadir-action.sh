upstream_upgrade_info() {
  echo -n "For upstream documentation about upgrading, see: "
  case ${MYSQL_VERSION} in
    10.0) echo "https://mariadb.com/kb/en/library/upgrading-from-mariadb-55-to-mariadb-100/" ;;
    10.1) echo "https://mariadb.com/kb/en/library/upgrading-from-mariadb-100-to-mariadb-101/" ;;
    10.2) echo "https://mariadb.com/kb/en/library/upgrading-from-mariadb-101-to-mariadb-102/" ;;
    5.6) echo "https://dev.mysql.com/doc/refman/5.6/en/upgrading-from-previous-series.html" ;;
    5.7) echo "https://dev.mysql.com/doc/refman/5.7/en/upgrading-from-previous-series.html" ;;
    8.0) echo "https://dev.mysql.com/doc/refman/8.0/en/upgrading-from-previous-series.html" ;;
    *) echo "Non expected version '${MYSQL_VERSION}'" ; return 1 ;;
  esac
}

check_datadir_version() {
  local datadir="$1"
  local datadir_version=$(get_datadir_version "$datadir")
  local mysqld_version=$(mysqld_compat_version)
  local datadir_version_dot=$(number2version "${datadir_version}")
  local mysqld_version_dot=$(number2version "${mysqld_version}")

  for datadir_action in ${MYSQL_DATADIR_ACTION//,/ } ; do
    log_info "Running datadir action: ${datadir_action}"
    case ${datadir_action} in
      upgrade-auto|upgrade-warn)
        if [ -z "${datadir_version}" ] || [ "${datadir_version}" -eq 0 ] ; then
          # Writing the info file, since historically it was not written
          log_warn "Version of the data could not be determined."\
                   "It is because the file mysql_upgrade_info is missing in the data directory, which"\
                   "is most probably because it was not created when initialization of data directory."\
                   "In order to allow seamless updates to the next higher version in the future,"\
                   "the file mysql_upgrade_info will be created."\
                   "If the data directory was created with a different version than ${mysqld_version_dot},"\
                   "it is required to run this container with the MYSQL_DATADIR_ACTION environment variable"\
                   "set to 'force', or run 'mysql_upgrade' utility manually; the mysql_upgrade tool"\
                   "checks the tables and creates such a file as well. $(upstream_upgrade_info)"
          write_mysql_upgrade_info_file "${MYSQL_DATADIR}"
          continue
          # This is currently a dead-code, but should be enabled after the mysql_upgrade_info
          # file gets to the deployments (after few months most of the deployments should already have the file)
          log_warn "Version of the data could not be determined."\
                   "Running such a container is risky."\
                   "The current daemon version is ${mysqld_version_dot}."\
                   "If you are not sure whether the data directory is compatible with the current"\
                   "version ${mysqld_version_dot}, restore the data from a back-up."\
                   "If restoring from a back-up is not possible, create a file 'mysql_upgrade_info'"\
                   "that includes version information (${mysqld_version_dot} in this case) in the root"\
                   "of the data directory."\
                   "In order to create the 'mysql_upgrade_info' file, either run this container with"\
                   "the MYSQL_DATADIR_ACTION environment variable set to 'force', or run 'mysql_upgrade' utility"\
                   "manually; the mysql_upgrade tool checks the tables and creates such a file as well."\
                   "That will enable correct upgrade check in the future. $(upstream_upgrade_info)"
        fi

        if [ "${datadir_version}" -eq "${mysqld_version}" ] ; then
          log_info "MySQL server version check passed, both server and data directory"\
                   "are version ${mysqld_version_dot}."
          continue
        fi

        if [ $(( ${datadir_version} + 1 )) -eq "${mysqld_version}" -o "${datadir_version}" -eq 505 -a "${mysqld_version}" -eq 1000 \
                   -o "${datadir_version}" -eq 507 -a "${mysqld_version}" -eq 800 ]; then
          log_warn "MySQL server is version ${mysqld_version_dot} and datadir is version"\
                   "${datadir_version_dot}, which is a compatible combination."
          if [ "${MYSQL_DATADIR_ACTION}" == 'upgrade-auto' ] ; then
            log_info "The data directory will be upgraded automatically from ${datadir_version_dot}"\
                     "to version ${mysqld_version_dot}. $(upstream_upgrade_info)"
            log_and_run mysql_upgrade ${mysql_flags}
          else
            log_warn "Automatic upgrade is not turned on, proceed with the upgrade."\
                     "In order to upgrade the data directory, run this container with the MYSQL_DATADIR_ACTION"\
                     "environment variable set to 'upgrade-auto' or run mysql_upgrade manually. $(upstream_upgrade_info)"
          fi
        else
          log_warn "MySQL server is version ${mysqld_version_dot} and datadir is version"\
                   "${datadir_version_dot}, which are incompatible. Remember, that upgrade is only supported"\
                   "by upstream from previous version and it is not allowed to skip versions. $(upstream_upgrade_info)"
          if [ "${datadir_version}" -gt "${mysqld_version}" ] ; then
            log_warn "Downgrading to the lower version is not supported. Consider"\
                     "dumping data and load them again into a fresh instance. $(upstream_upgrade_info)"
          fi
          log_warn "Consider restoring the database from a back-up. To ignore this"\
                   "warning, set 'MYSQL_DATADIR_ACTION' variable to 'upgrade-force', but this may result in data corruption. $(upstream_upgrade_info)"
          return 1
        fi
        ;;

      upgrade-force)
        log_and_run mysql_upgrade ${mysql_flags} --force
        ;;

      optimize)
        log_and_run mysqlcheck ${mysql_flags} --optimize --all-databases --force
        ;;

      analyze)
        log_and_run mysqlcheck ${mysql_flags} --analyze --all-databases --force
        ;;

      disable)
        log_info "Nothing is done about the data directory."
        ;;
      *)
        log_warn "Unknown value of MYSQL_DATADIR_ACTION variable: '${MYSQL_DATADIR_ACTION}', ignoring."
        ;;
    esac
  done
}

check_datadir_version "${MYSQL_DATADIR}"

unset -f check_datadir_version upstream_upgrade_info


