configure_file(
  input: 'mainline.desktop.in',
  output: 'mainline.desktop',
  configuration: {
    'BRANDING_LONGNAME': 'Mainline Kernels (Arch Linux)',
    'BRANDING_SHORTNAME': 'mainline',
  },
  install_dir: get_option('datadir') / 'applications'
)

# Instalação de ícones e pixmaps
install_data('tux-red.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('tux.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('arch-logo.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('pixmaps/mainline.svg', install_dir: get_option('datadir') / 'pixmaps')
