glib_dep = dependency('glib-2.0')
gio_dep = dependency('gio-unix-2.0')
gee_dep = dependency('gee-0.8')
json_dep = dependency('json-glib-1.0')
posix_dep = meson.get_compiler('vala').find_library('posix')

cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required: false)

gtk_dep = dependency('gtk+-3.0')
vte_dep = dependency('vte-2.91')
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
  dependencies: [glib_dep, gio_dep, gee_dep, json_dep, posix_dep, gtk_dep, vte_dep, x11_dep, m_dep],
  install: true
)
