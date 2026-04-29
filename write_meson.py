import os

# Caminho base do projeto
base = '/home/john/Projects/mainline'

meson_root = """project('mainline', ['vala', 'c'],
  version: '1.4.13',
  meson_version: '>= 0.50.0',
)

prefix = get_option('prefix')
c_args = [
  '-DINSTALL_PREFIX="' + prefix + '"',
  '-DBRANDING_SHORTNAME="mainline"',
  '-DBRANDING_LONGNAME="Mainline Kernels"',
  '-DBRANDING_VERSION="1.4.13"',
  '-DBRANDING_COPYRIGHT="2019"',
  '-DBRANDING_AUTHORNAME="Brian K. White"',
  '-DBRANDING_AUTHOREMAIL="b.kenyon.w@gmail.com"',
  '-DBRANDING_WEBSITE="https://github.com/bkw777/mainline"',
  '-DGETTEXT_PACKAGE="mainline"',
]

# Gera a macro TRANSLATORS
translators_cmd = run_command('sh', '-c', 'grep \\'^"Last-Translator: \\' po/*.po | while IFS=\\'/.:\\' read x l x x n ; do echo "$l:${n%\\\\n*}"; done | tr "\\n" " " || true', check: false)
translators = translators_cmd.stdout().strip()
c_args += '-DTRANSLATORS="' + translators + '"'

add_project_arguments(c_args, language: 'c')

vala_args = [
  '--target-glib=2.32',
  '-D', 'GLIB_JSON_1_6',
  '-D', 'VTE_0_72',
  '-D', 'VTE_0_66'
]
add_project_arguments(vala_args, language: 'vala')

subdir('data')
subdir('src')
subdir('po')
"""

meson_src = """glib_dep = dependency('glib-2.0')
gio_dep = dependency('gio-unix-2.0')
gee_dep = dependency('gee-0.8')
json_dep = dependency('json-glib-1.0')
posix_dep = meson.get_compiler('vala').find_library('posix')

cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required: false)

# Dependências atualizadas para GTK4 e Libadwaita
gtk_dep = dependency('gtk4')
adw_dep = dependency('libadwaita-1')
vte_dep = dependency('vte-2.91-gtk4')
x11_dep = dependency('x11')

common_sources = files([
  'Common/DownloadManager.vala',
  'Common/LinuxKernel.vala',
  'Common/Main.vala',
  'Common/Package.vala',
  'lib/AsyncTask.vala',
  'lib/l_exec.vala',
  'lib/l_json.vala',
  'lib/l_misc.vala'
])

console_sources = files([
  'Console/AppConsole.vala'
])

gtk_sources = files([
  'Gtk/AppGtk.vala',
  'Gtk/MainWindow.vala',
  'Gtk/SettingsWindow.vala',
  'Gtk/TerminalWindow.vala'
])

executable('mainline',
  common_sources + console_sources,
  dependencies: [glib_dep, gio_dep, gee_dep, json_dep, posix_dep, m_dep],
  install: true
)

executable('mainline-gtk',
  common_sources + gtk_sources,
  dependencies: [glib_dep, gio_dep, gee_dep, json_dep, posix_dep, gtk_dep, adw_dep, vte_dep, x11_dep, m_dep],
  install: true
)
"""

meson_data = """install_data('mainline.desktop.in',
  install_dir: get_option('datadir') / 'applications',
  rename: 'mainline.desktop'
)

# Instalação de ícones e pixmaps
install_data('main_window.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('sort_by_locked.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('sort_by_notes.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('sort_by_status.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('tux-red.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('tux.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
install_data('ubuntu-logo.png', install_dir: get_option('datadir') / 'pixmaps/mainline')
"""

meson_po = """i18n = import('i18n')
i18n.gettext('mainline', preset: 'glib')
"""

# Escrita dos arquivos
with open(f"{base}/meson.build", "w") as f:
    f.write(meson_root)

with open(f"{base}/src/meson.build", "w") as f:
    f.write(meson_src)

with open(f"{base}/data/meson.build", "w") as f:
    f.write(meson_data)

with open(f"{base}/po/meson.build", "w") as f:
    f.write(meson_po)

print("Meson setup (GTK4) complete.")
