local _MODREV, _SPECREV = 'scm', '-1'
rockspec_format = "3.0"
package = 'nvim-notify'
version = _MODREV .. _SPECREV

description = {
   summary = 'A fancy, configurable, notification manager for NeoVim ',
   labels = {
     'neovim',
     'plugin'
     'nvim'
   },
   homepage = 'http://github.com/rcarriga/nvim-notify',
   license = 'MIT',
}

dependencies = {
   'lua >= 5.1',
}

source = {
   url = 'git://github.com/rcarriga/nvim-notify',
}

build = {
   type = 'builtin',
   copy_directories = {
     'doc'
   },
}
