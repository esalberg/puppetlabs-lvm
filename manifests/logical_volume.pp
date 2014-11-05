# == Define: lvm::logical_volume
#
define lvm::logical_volume (
  $volume_group,
  $size,
  $ensure            = present,
  $options           = 'defaults',
  $fs_type           = 'ext4',
  $mountpath         = "/${name}",
  $mountpath_require = false,
  $restore_content   = false,
  $restore_service   = '',
  $restore_file      = "/tmp/restore-${name}.tar",
) {

  validate_bool($mountpath_require)
  validate_bool($restore_content)
  validate_string($restore_file)

  if $mountpath_require {
    Mount {
      require => File[$mountpath],
    }
  }

  $mount_ensure = $ensure ? {
    'absent' => absent,
    default  => mounted,
  }

  if $ensure == 'present' {
    Logical_volume[$name] ->
    Filesystem["/dev/${volume_group}/${name}"] ->
    Mount[$mountpath]
  } else {
    Mount[$mountpath] ->
    Filesystem["/dev/${volume_group}/${name}"] ->
    Logical_volume[$name]
  }

  logical_volume { $name:
    ensure       => $ensure,
    volume_group => $volume_group,
    size         => $size,
  }

  filesystem { "/dev/${volume_group}/${name}":
    ensure  => $ensure,
    fs_type => $fs_type,
  }

# Create mountpoint if it does not exist
  exec { "ensure mountpoint '${mountpath}' exists":
    path    => [ '/bin', '/usr/bin', '/sbin' ],
    command => "mkdir -p ${mountpath}",
    unless  => "test -d ${mountpath}",
  } ->
# Stop service if service named, mount not mounted
  exec { "restore_content: stop ${restore_service}":
    path      => [ '/bin', '/usr/bin', '/sbin' ],
    cwd       => $mountpath,
    command   => "service ${restore_service} stop",
    logoutput => true,
    onlyif    => ["test ${restore_service}",
                  "test `mount | grep '${mountpath} ' | wc -l` -eq 0"],
  } ->
# Save and cleanup local data if restoring content, mount not mounted
#  local dir has content, restore_file does not exist
  exec { "save and cleanup data from '${mountpath}'":
    path      => [ '/bin', '/usr/bin', '/sbin' ],
    cwd       => $mountpath,
    command   => "tar -cf ${restore_file} * && rm -rf ${mountpath}/*",
    logoutput => true,
    onlyif    => ["test `mount | grep '${mountpath} ' | wc -l` -eq 0",
                  "test ! -f ${restore_file}",
                  "test '${restore_content}' = 'true'",
                  "test ! `ls ${mountpath} | wc -l` -eq 0"],
  } ->
# Mount mountpath
  mount { $mountpath:
    ensure  => $mount_ensure,
    device  => "/dev/${volume_group}/${name}",
    fstype  => $fs_type,
    options => $options,
    pass    => 2,
    dump    => 1,
    atboot  => true,
  } ->
# If restoring content, a restore file exists, and mount is empty
#  put local content onto mount
  exec { "restore data to '${mountpath}'":
    path      => [ '/bin', '/usr/bin', '/sbin' ],
    command   => "tar -xf ${restore_file} && rm -f ${restore_file}",
    cwd       => $mountpath,
    logoutput => true,
    onlyif    => ["test -f ${restore_file}",
                  "test '${restore_content}' = 'true'",
                  "test `ls ${mountpath} | grep -v lost+found | wc -l` -eq 0"],
  } ->
# Start service if service named and service not running
  exec { "restore_content: start ${restore_service}":
    path      => [ '/bin', '/usr/bin', '/sbin' ],
    cwd       => $mountpath,
    command   => "/sbin/service ${restore_service} start",
    logoutput => true,
    onlyif    => ["test ${restore_service}",
                  "service ${restore_service} status | grep 'is running' | wc -l 0"],
  } ->
# Warn if restore file still remains
  exec { "legacy ${restore_file} exists for ${mountpath}":
    path      => [ '/bin', '/usr/bin', '/sbin' ],
    command   => "echo Please review and cleanup ${restore_file}!",
    logoutput => true,
    loglevel  => 'warning',
    onlyif    => "test -f ${restore_file}",
  }
}
