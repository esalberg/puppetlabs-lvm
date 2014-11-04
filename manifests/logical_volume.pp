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
  $restore_file      = '/tmp/restore.tar',
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

  exec { "ensure mountpoint '${mountpath}' exists":
    path    => [ '/bin', '/usr/bin' ],
    command => "mkdir -p ${mountpath}",
    unless  => "test -d ${mountpath}",
  } ->
  exec { "save and cleanup data from '${mountpath}'":
    path      => [ '/bin', '/usr/bin' ],
    cwd       => $mountpath,
    command   => "tar -cf ${restore_file} * && rm -rf ${mountpath}/*",
    logoutput => true,
# Only if $restore_content, ${mountpath} is not mounted working directory 
# is not empty and ${restore_file} does not exist
    onlyif    => ["test ! `mount | grep '${mountpath} '` >/dev/null 2>&1",
                  "test ! -f ${restore_file}",
                  "test ! `ls ${mountpath} | wc -l` -eq 0",
                  "test ! ${restore_content}=false"],
  } ->
  mount { $mountpath:
    ensure  => $mount_ensure,
    device  => "/dev/${volume_group}/${name}",
    fstype  => $fs_type,
    options => $options,
    pass    => 2,
    dump    => 1,
    atboot  => true,
  } ->
  exec { "restore data to '${mountpath}'":
    path      => [ '/bin', '/usr/bin' ],
    command   => "tar -xf ${restore_file} && rm -f ${restore_file}",
    cwd       => $mountpath,
    logoutput => true,
# Only if $restore_content, ${restore_file} is a file and ${mountpath} is empty
    onlyif    => ["test -f ${restore_file}",
                  "test `ls ${mountpath} | grep -v lost+found | wc -l` -eq 0",
                  "test ! ${restore_content}=false"],
  } ->
  exec { "Legacy ${restore_file} file exists":
    path      => [ '/bin', '/usr/bin' ],
    command   => "echo Please review and cleanup ${restore_file}!",
    logoutput => true,
    loglevel  => 'warning',
    onlyif    => "test -f ${restore_file}",
  }
}
