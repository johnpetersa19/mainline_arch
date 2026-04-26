project('mainline', ['vala', 'c'],
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

# Generate TRANSLATORS macro
translators_cmd = run_command('sh', '-c', 'grep \'^"Last-Translator: \' po/*.po | while IFS=\'/.:\' read x l x x n ; do echo "$l:${n%\\n*}"; done | tr "\n" " " || true', check: false)
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
