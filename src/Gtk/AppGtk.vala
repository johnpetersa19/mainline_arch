/*
 * AppGtk.vala
 *
 * Copyright 2016 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

using l_misc;
using Adw;

public Main App;

public class AppGtk : Adw.Application {

	public AppGtk() {
		ApplicationFlags flags = ApplicationFlags.DEFAULT_FLAGS;
		string? id = "org.bkw777.mainline";
		if (Posix.getuid() == 0) {
			id = null;
			flags |= ApplicationFlags.NON_UNIQUE;
		}
		Object(application_id: id, flags: flags);
	}

	protected override void startup() {
		base.startup();

		// Add local pixmaps to search path for development
		var icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
		string path = Path.build_filename(Environment.get_current_dir(), "data", "pixmaps");
		if (FileUtils.test(path, FileTest.IS_DIR)) icon_theme.add_search_path(path);
		
		// Also try the hardcoded path as fallback
		icon_theme.add_search_path("/home/john/Projects/mainline/data/pixmaps");
	}

	protected override void activate() {
		var win = active_window ?? new MainWindow(this);
		win.present();
	}

	public static int main(string[] argv) {
		Gdk.set_allowed_backends("wayland,x11,*");
		App = new Main();
		App.gui_mode = true;
		parse_arguments(argv);
		vprint(string.joinv(" ",argv),3);
		App.init2();

		// When running as root (via pkexec/sudo), the D-Bus session socket
		// belongs to the original user and is not accessible to the elevated
		// process, causing GLib to emit "Error writing credentials to socket"
		// warnings. Unsetting DBUS_SESSION_BUS_ADDRESS prevents GLib/GIO from
		// attempting to connect to the inaccessible socket.
		if (Posix.getuid() == 0) {
			GLib.Environment.unset_variable("DBUS_SESSION_BUS_ADDRESS");
			GLib.Environment.unset_variable("DBUS_SYSTEM_BUS_ADDRESS");
			GLib.Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
		}

		return new AppGtk().run(argv);
	}

	public static bool parse_arguments(string[] args) {

		string help = ""
		+ "\n" + BRANDING_SHORTNAME + " " + BRANDING_VERSION + " - " + BRANDING_LONGNAME + "\n"
		+ "\n"
		+ _("Syntax") + ": " + args[0] + " ["+_("command")+"] ["+_("options")+"]\n"
		+ "\n"
		+ _("Commands") + "\n"
		+ "  help                " + _("This help") + "\n"
		+ "\n"
		+ _("Options") + "\n"
		+ "  -v|--verbose [#]    " + _("Set verbosity level to #, or increment by 1") + "\n"
		+ "\n"
		;

		// parse options
		for (int i = 1; i < args.length; i++)
		{
			switch (args[i].down()) {

			// this is the notification action
			case "--install":
			case "install":
				App.command = "install";
				if (++i < args.length) App.requested_versions = args[i].down();
				break;

			case "-v":
			case "--debug":
			case "--verbose":
				if (App.set_verbose(args[i+1])) i++;
				break;

			case "-?":
			case "-h":
			case "--help":
			case "help":
			case "--version":
				vprint(help,0);
				exit(0);
				break;

			default:
				vprint(_("Unknown option") + ": \""+args[i]+"\"",1,stderr);
				vprint(help,0);
				exit(1);
				break;

			}
		}

		return true;
	}

	public static void alert(Gtk.Window win, string msg) {
		var dialog = new Adw.AlertDialog(_("Information"), msg);
		dialog.add_response("ok", _("OK"));
		dialog.present(win);
	}

}
