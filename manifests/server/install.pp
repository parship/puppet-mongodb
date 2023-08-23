# PRIVATE CLASS: do not call directly
class mongodb::server::install {
  $package_ensure       = $mongodb::server::package_ensure
  $package_name         = $mongodb::server::package_name
  $mongosh_package_name = $mongodb::server::mongosh_package_name

  case $package_ensure {
    true:     {
      $my_package_ensure = 'present'
      $file_ensure     = 'directory'
    }
    false:    {
      $my_package_ensure = 'absent'
      $file_ensure     = 'absent'
    }
    'absent': {
      $my_package_ensure = 'absent'
      $file_ensure     = 'absent'
    }
    'purged': {
      $my_package_ensure = 'purged'
      $file_ensure     = 'absent'
    }
    default:  {
      $my_package_ensure = $package_ensure
      $file_ensure     = 'present'
    }
  }

  unless defined(Package[$package_name]) {
    package { 'mongodb_server':
      ensure => $my_package_ensure,
      name   => $package_name,
      tag    => 'mongodb_package',
    }
  }
  unless defined(Package[$mongosh_package_name]) {
    package { 'mongodb_mongosh':
      ensure => present,
      name   => $mongosh_package_name,
      tag    => 'mongodb_mongosh_package',
    }
  }
}
