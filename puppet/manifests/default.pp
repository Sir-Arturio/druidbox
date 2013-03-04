# Basic Puppet manifest

Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

class system-update {

    file { "/etc/apt/sources.list.d/dotdeb.list":
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/apt/dotdeb.list",
    }

    exec { 'dotdeb-apt-key':
        cwd     => '/tmp',
        command => "sudo wget http://www.dotdeb.org/dotdeb.gpg -O dotdeb.gpg &&
                    sudo cat dotdeb.gpg | sudo apt-key add -",
        unless  => 'apt-key list | grep dotdeb',
        require => File['/etc/apt/sources.list.d/dotdeb.list'],
        notify  => Exec['apt_update'],
    }

  exec { 'apt-get update':
    command => 'sudo apt-get update',
  }

  $sysPackages = [ "build-essential" ]
  package { $sysPackages:
    ensure => "installed",
    require => Exec['apt-get update'],
  }
}

class nginx-setup {

  include nginx

  file { "/etc/nginx/sites-available/php-fpm":
    owner  => root,
    group  => root,
    mode   => 664,
    source => "/vagrant/conf/nginx/default",
    require => Package["nginx"],
    notify => Service["nginx"],
  }

  file { "/etc/nginx/sites-enabled/default":
    owner  => root,
    ensure => link,
    target => "/etc/nginx/sites-available/php-fpm",
    require => Package["nginx"],
    notify => Service["nginx"],
  }
}

class development {

  $devPackages = [ "curl", "git", "nodejs", "npm", "capistrano", "rubygems", "openjdk-7-jdk", "libaugeas-ruby" ]
  package { $devPackages:
    ensure => "installed",
    require => Exec['apt-get update'],
  }

  exec { 'install less using npm':
    command => 'sudo npm install less -g',
    require => Package["npm"],
  }

  exec { 'install capistrano_rsync_with_remote_cache using RubyGems':
    command => 'sudo gem install capistrano_rsync_with_remote_cache',
    require => Package["capistrano"],
  }
}

class devbox_php_fpm {

    php::module { [
        'curl', 'gd', 'mcrypt', 'memcached', 'mysql',
        'tidy', 'imap',
        ]:
        notify => Class['php::fpm::service'],
    }

    php::module { [ 'memcache']:
        notify => Class['php::fpm::service'],
        source  => '/etc/php5/conf.d/',
    }

    php::module { [ 'xhprof', ]:
          notify => Class['php::fpm::service'],
          package_prefix => 'php-',
          source  => '/etc/php5/conf.d/',
      }

    php::module { [ 'apc', ]:
          notify => Class['php::fpm::service'],
          source  => '/etc/php5/conf.d/',
          package_prefix => 'php-',
      }

    php::module { [ 'xdebug', ]:
        notify  => Class['php::fpm::service'],
        source  => '/etc/php5/conf.d/',
    }

    php::module { [ 'suhosin', ]:
        notify  => Class['php::fpm::service'],
        source  => '/vagrant/conf/php/',
    }
    
    exec { 'pecl-mongo-install':
        command => 'pecl install mongo',
        unless => "pecl info mongo",
        notify => Class['php::fpm::service'],
        require => Package['php-pear'],
    }

    exec { 'pecl-xhprof-install':
        command => 'pecl install xhprof-0.9.2',
        unless => "pecl info xhprof",
        notify => Class['php::fpm::service'],
        require => Package['php-pear'],
    }

    php::conf { [ 'mysqli', 'pdo', 'pdo_mysql', ]:
        require => Package['php-mysql'],
        notify  => Class['php::fpm::service'],
    }

    file { "/etc/php5/conf.d/custom.ini":
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/php/custom.ini",
        notify => Class['php::fpm::service'],
    }

    file { "/etc/php5/fpm/pool.d/www.conf":
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/php/php-fpm/www.conf",
        notify => Class['php::fpm::service'],
    }
}

class { 'apt':
  always_apt_update    => true
}

class drupal {

  exec { 'discover drush pear channel':
    command => 'sudo pear channel-discover pear.drush.org; true',
    logoutput => "on_failure",
    require => Package['php-pear'],
  }

  exec { 'install latest Drush':
    command => 'sudo pear install drush/drush',
    logoutput => "on_failure",
    require => [Package['php-pear'],Exec["discover drush pear channel"]],
  }

  exec { 'create .drush folder':
    command => 'sudo drush',
    logoutput => "on_failure",
    require => Exec["install latest Drush"],
    creates => "/home/vagrant/.drush"
  }

  exec { 'Chown .drush to vagrant user':
    command => 'sudo chown -R vagrant:vagrant /home/vagrant/.drush',
    logoutput => "on_failure",
    require => Exec["create .drush folder"],
  }

}

Exec["apt-get update"] -> Package <| |>

include system-update

include php::fpm
include php::apache2
include devbox_php_fpm
include pear
include nginx-setup
include apache
include mysql

class {'mongodb':
  enable_10gen => true,
}

# include phpqatools
include development
include drupal
