# == Define: lvm::volume_group
#
define lvm::volume_group (
  $physical_volumes,
  $ensure          = present,
  $logical_volumes = {},
  $unless_vg       = undef,
  $createonly      = false,
  $lv_fact_match   = undef,
) {

  validate_hash($logical_volumes)

  if ! $lv_fact_match {
    physical_volume { $physical_volumes:
      ensure => $ensure,
    }

    volume_group { $name:
      ensure           => $ensure,
      physical_volumes => $physical_volumes,
      createonly       => $createonly,
    }

    create_resources(
      'lvm::logical_volume',
      $logical_volumes,
      {
        ensure       => $ensure,
        volume_group => $name,
      }
    )
  }
}
