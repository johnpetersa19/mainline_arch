project('mainline', ['vala', 'c'],
  version: '1.5.0',
  meson_version: '>= 0.50.0',
)

prefix = get_option('prefix')
if prefix == '/usr/local'
  prefix = '/usr'
endif
c_args = [
  # Suppress warnings from Vala-generated C code (not fixable in Vala source)
  '-Wno-unused-variable',
  '-Wno-unused-but-set-variable',
  '-Wno-pointer-sign',
  '-Wno-deprecated-declarations',
  '-DINSTALL_PREFIX="' + prefix + '"',
  '-DBRANDING_SHORTNAME="mainline"',
  '-DBRANDING_LONGNAME="Mainline Kernels (Arch Linux)"',
  '-DBRANDING_VERSION="1.5.0"',
  '-DBRANDING_COPYRIGHT="2026"',
  '-DBRANDING_AUTHORNAME="Mainline Project Contributors"',
  '-DBRANDING_AUTHOREMAIL="johnppetersa@gmail.com"',
  '-DBRANDING_WEBSITE="https://github.com/johnpetersa19/mainline_arch"',
  '-DGETTEXT_PACKAGE="mainline"',
]

# Gera a macro TRANSLATORS
translators_cmd = run_command('sh', '-c', 'grep \'^"Last-Translator: \' po/*.po | while IFS=\'/.:\' read x l x x n ; do echo "$l:${n%\\n*}"; done | tr "\n" " " || true', check: false)
translators = translators_cmd.stdout().strip()
c_args += '-DTRANSLATORS="' + translators + '"'

add_project_arguments(c_args, language: 'c')

vala_args = [
  '--target-glib=2.86',
  '-D', 'GLIB_JSON_1_6',
]
add_project_arguments(vala_args, language: 'vala')

subdir('data')
subdir('src')
subdir('po')
