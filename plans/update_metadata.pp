# == Plan: boltello::update_metadata
#
plan boltello::update_metadata(
  TargetSpec $katello,
  String $boltdir = boltello::get_boltdir(),
  Pattern[/^\d+\.\d{2}$/] $katello_version,
  Pattern[/^\d+\.\d{2}$/] $foreman_version
) {
  apply($katello, _catch_errors => true, _description => 'ensure boltello project metadata versions') {
    file_line { 'set foreman_version':
      path  => "${boltdir}/data/common.yaml",
      line  => "'boltello::foreman_version': '${foreman_version}'",
      match => "'boltello::foreman_version':",
    }

    file_line { 'set katello_version':
      path  => "${boltdir}/data/common.yaml",
      line  => "'boltello::katello_version': '${katello_version}'",
      match => "'boltello::katello_version':",
    }
  }
}
