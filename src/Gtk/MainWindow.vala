/*
 * MainWindow.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
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
 *
 *
 */

using Gtk;
using Adw;

using l_misc;
using l_exec;

public class MainWindow : Adw.ApplicationWindow {

	const int SPACING = 6;

	Adw.ToolbarView toolbar_view;
	Adw.ToastOverlay toast_overlay;
	Box vbox_main;
	Box hbox_list;

	Button btn_install;
	Button btn_uninstall;
	Button btn_uninstall_old;
	Button btn_reload;
	Label lbl_info;
	Gtk.Spinner spn_info;
	Adw.HeaderBar header_bar;
	Gdk.Texture? pix_arch;
	Gdk.Texture? pix_mainline;
	Gdk.Texture? pix_mainline_rc;
	Gdk.Cursor cursor_busy;

	bool is_binding = false;

	bool updating;

	Gee.ArrayList<LinuxKernel> selected_kernels;
	GLib.ListStore tm;
	Gtk.SortListModel sort_model;
	Gtk.MultiSelection sel_model;
	Gtk.ColumnView tv;

	public MainWindow(Adw.Application app) {
		Object(application: app);

		set_default_size(App.window_width, App.window_height);

		title = BRANDING_LONGNAME;
		cursor_busy = new Gdk.Cursor.from_name("wait", null);

		selected_kernels = new Gee.ArrayList<LinuxKernel>();
		tm = new GLib.ListStore(typeof(LinuxKernel));
		sort_model = new Gtk.SortListModel(tm, null);
		sel_model = new Gtk.MultiSelection(sort_model);
		tv = new Gtk.ColumnView(sel_model);

		pix_arch        = load_texture("arch-logo.png");
		pix_mainline    = load_texture("tux.png");
		pix_mainline_rc = load_texture("tux-red.png");

		toolbar_view = new Adw.ToolbarView();
		set_content(toolbar_view);

		header_bar = new Adw.HeaderBar();
		toolbar_view.add_top_bar(header_bar);

		toast_overlay = new Adw.ToastOverlay();
		toolbar_view.set_content(toast_overlay);

		vbox_main = new Box(Orientation.VERTICAL, 0);
		vbox_main.margin_top = vbox_main.margin_bottom = vbox_main.margin_start = vbox_main.margin_end = SPACING;
		toast_overlay.set_child(vbox_main);

		init_ui();
		update_cache();
	}

	void init_ui() {
		init_treeview();
		init_actions();
		init_infobar();
	}

	void init_treeview() {
		hbox_list = new Box(Orientation.HORIZONTAL, SPACING);
		vbox_main.append(hbox_list);

		tv.hexpand = true;
		tv.vexpand = true;
		tv.show_row_separators = true;
		tv.show_column_separators = true;

		tv.activate.connect((pos) => { set_button_state(); });

		sel_model.selection_changed.connect((position, n_items) => {
			tv_selection_changed();
		});

		var scrollwin = new ScrolledWindow();
		scrollwin.set_child(tv);
		hbox_list.append(scrollwin);

		// ── Kernel column (icon + version label) ────────────────────────
		var factory_kernel = new Gtk.SignalListItemFactory();
		factory_kernel.setup.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
			box.margin_start = SPACING;
			box.margin_end   = SPACING;
			var img = new Gtk.Image();
			img.pixel_size = 24;
			var lbl = new Gtk.Label("");
			lbl.ellipsize = Pango.EllipsizeMode.END;
			lbl.xalign    = 0;
			lbl.hexpand   = true;
			box.append(img);
			box.append(lbl);
			li.set_child(box);
		});
		factory_kernel.bind.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var k   = (LinuxKernel) li.get_item();
			var box = (Gtk.Box) li.get_child();
			var img = (Gtk.Image) box.get_first_child();
			var lbl = (Gtk.Label) img.get_next_sibling();

			Gdk.Texture? p = pix_mainline;
			if (k.is_unstable) p = pix_mainline_rc;
			if (!k.is_mainline) p = pix_arch;

			if (p != null) {
				img.set_from_paintable(p);
			} else {
				// Fallback to system icons if custom files are missing
				if (k.is_mainline) img.set_from_icon_name("linux-symbolic");
				else img.set_from_icon_name("operating-system-symbolic");
			}
#if DISPLAY_VERSION_SORT
			lbl.set_label(k.version_sort);
#else
			lbl.set_label(k.version_main);
#endif
			box.set_tooltip_text(k.tooltip_text());
		});

		var col_kernel = new Gtk.ColumnViewColumn(_("Kernel"), factory_kernel);
		col_kernel.resizable  = true;
		col_kernel.expand     = true;
		col_kernel.fixed_width = 200;
		col_kernel.sorter = new Gtk.CustomSorter((a, b) => {
			return ((LinuxKernel) a).compare_to((LinuxKernel) b);
		});
		tv.append_column(col_kernel);

		// ── Date column ──────────────────────────────────────────────────
		var factory_date = new Gtk.SignalListItemFactory();
		factory_date.setup.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var lbl = new Gtk.Label("");
			lbl.xalign    = 0;
			lbl.ellipsize = Pango.EllipsizeMode.END;
			lbl.margin_start = SPACING;
			lbl.margin_end   = SPACING;
			li.set_child(lbl);
		});
		factory_date.bind.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var k   = (LinuxKernel) li.get_item();
			var lbl = (Gtk.Label) li.get_child();
			lbl.set_label(k.release_date);
		});

		var col_date = new Gtk.ColumnViewColumn(_("Date"), factory_date);
		col_date.resizable = true;
		tv.append_column(col_date);

		// ── Lock column (checkbox toggle) ────────────────────────────────
		var factory_lock = new Gtk.SignalListItemFactory();
		factory_lock.setup.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var cb = new Gtk.CheckButton();
			cb.halign = Gtk.Align.CENTER;
			li.set_child(cb);
			// connect once; read current item via closure over li
			cb.notify["active"].connect(() => {
				if (is_binding) return;
				var k = li.get_item() as LinuxKernel;
				if (k != null && cb.active != k.is_locked) {
					k.set_locked(cb.active);
					set_button_state();
				}
			});
		});
		factory_lock.bind.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var k  = (LinuxKernel) li.get_item();
			var cb = (Gtk.CheckButton) li.get_child();
			// block signal temporarily so bind doesn't trigger toggled
			is_binding = true;
			cb.active = k.is_locked;
			is_binding = false;
		});

		var col_lock = new Gtk.ColumnViewColumn(_("Lock"), factory_lock);
		col_lock.sorter = new Gtk.CustomSorter((a, b) => {
			int ia = ((LinuxKernel) a).is_locked ? 1 : 0;
			int ib = ((LinuxKernel) b).is_locked ? 1 : 0;
			return ia - ib;
		});
		tv.append_column(col_lock);

		// ── Status column ────────────────────────────────────────────────
		var factory_status = new Gtk.SignalListItemFactory();
		factory_status.setup.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var lbl = new Gtk.Label("");
			lbl.xalign    = 0;
			lbl.ellipsize = Pango.EllipsizeMode.END;
			lbl.margin_start = SPACING;
			lbl.margin_end   = SPACING;
			li.set_child(lbl);
		});
		factory_status.bind.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var k   = (LinuxKernel) li.get_item();
			var lbl = (Gtk.Label) li.get_child();
			lbl.set_label(k.status);
			lbl.set_tooltip_text(k.tooltip_text());
		});

		var col_status = new Gtk.ColumnViewColumn(_("Status"), factory_status);
		col_status.resizable = true;
		col_status.sorter = new Gtk.CustomSorter((a, b) => {
			return strcmp(((LinuxKernel) a).status, ((LinuxKernel) b).status);
		});
		tv.append_column(col_status);

		// ── Notes column (inline editable) ──────────────────────────────
		var factory_notes = new Gtk.SignalListItemFactory();
		factory_notes.setup.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var el = new Gtk.EditableLabel("");
			el.hexpand = true;
			el.margin_start = SPACING;
			el.margin_end   = SPACING;
			li.set_child(el);
			el.notify["editing"].connect(() => {
				if (!el.editing) {
					var k = li.get_item() as LinuxKernel;
					if (k != null) {
						var t_new = el.text.strip();
						if (k.notes.strip() != t_new) {
							k.set_notes(t_new);
						}
					}
				}
			});
		});
		factory_notes.bind.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var k  = (LinuxKernel) li.get_item();
			var el = (Gtk.EditableLabel) li.get_child();
			el.text = k.notes;
			el.set_tooltip_text(k.tooltip_text());
		});

		var col_notes = new Gtk.ColumnViewColumn(_("Notes"), factory_notes);
		col_notes.resizable   = true;
		col_notes.expand      = true;
		col_notes.fixed_width = 200;
		col_notes.sorter = new Gtk.CustomSorter((a, b) => {
			return strcmp(((LinuxKernel) a).notes, ((LinuxKernel) b).notes);
		});
		tv.append_column(col_notes);

		// Wire up the ColumnView's built-in sorter to the SortListModel
		sort_model.sorter = tv.sorter;
	}

	Gdk.Texture? load_texture(string name) {
		string[] paths = {
			INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/" + name,
			"/home/john/Projects/mainline/data/" + name,
			"./data/" + name,
			"../data/" + name,
			"/usr/share/pixmaps/" + BRANDING_SHORTNAME + "/" + name,
			"/usr/local/share/pixmaps/" + BRANDING_SHORTNAME + "/" + name
		};

		foreach (string path in paths) {
			if (GLib.FileUtils.test(path, GLib.FileTest.EXISTS)) {
				try {
					return Gdk.Texture.from_filename(path);
				} catch (Error e) { vprint(e.message, 1, stderr); }
			}
		}
		return null;
	}

	string get_cli_path() {
		try {
			string self_path = FileUtils.read_link("/proc/self/exe");
			string bin_dir = Path.get_dirname(self_path);
			string local_cli = Path.build_filename(bin_dir, CLI_EXE);
			if (FileUtils.test(local_cli, FileTest.EXISTS | FileTest.IS_EXECUTABLE)) {
				return local_cli;
			}
		} catch (Error e) {}
		return CLI_EXE;
	}

	void tv_selection_changed() {
		selected_kernels.clear();
		uint n = sel_model.get_n_items();
		for (uint i = 0; i < n; i++) {
			if (sel_model.is_selected(i)) {
				var k = sel_model.get_item(i) as LinuxKernel;
				if (k != null) selected_kernels.add(k);
			}
		}
		set_button_state();
	}

	void tv_refresh() {
		tm.remove_all();

		foreach (var k in LinuxKernel.kernel_list) {
			if (!k.is_installed) {
				if (k.is_invalid  && App.hide_invalid)  continue;
				if (k.is_unstable && App.hide_unstable) continue;
				if (k.flavor != "generic" && App.hide_flavors) continue;
			}
			tm.append(k);
		}

		selected_kernels.clear();
		updating = false;
		set_infobar();
		set_button_state();
	}

	void set_button_state() {
		btn_install.sensitive   = false;
		btn_uninstall.sensitive = false;

		if (updating) {
			btn_uninstall_old.sensitive = false;
			btn_reload.sensitive        = false;
			return;
		}

		btn_uninstall_old.sensitive = true;
		btn_reload.sensitive        = true;

		foreach (var k in selected_kernels) {
			if (k.is_installed) {
				if (!k.is_locked && !k.is_running) btn_uninstall.sensitive = true;
			} else if (!k.is_invalid) {
				btn_install.sensitive = true;
			}
		}
		
		// If ANY selected kernel is locked or running, disable uninstall for safety
		foreach (var k in selected_kernels) {
			if (k.is_locked || k.is_running) {
				btn_uninstall.sensitive = false;
				break;
			}
		}
	}

	void init_actions() {
		Button button;

		var hbox = new Box(Orientation.VERTICAL, SPACING);
		hbox_list.append(hbox);

		btn_install = new Button();
		var bc_install = new Adw.ButtonContent();
		bc_install.label = _("Install");
		bc_install.icon_name = "system-software-install-symbolic";
		btn_install.child = bc_install;
		btn_install.add_css_class("suggested-action");
		hbox.append(btn_install);
		btn_install.clicked.connect(() => { do_install(selected_kernels); });

		btn_uninstall = new Button();
		var bc_uninstall = new Adw.ButtonContent();
		bc_uninstall.label = _("Uninstall");
		bc_uninstall.icon_name = "user-trash-symbolic";
		btn_uninstall.child = bc_uninstall;
		btn_uninstall.add_css_class("destructive-action");
		hbox.append(btn_uninstall);
		btn_uninstall.clicked.connect(() => { do_uninstall(selected_kernels); });

		button = new Button.with_label("Repo");
		button.set_tooltip_text(_("Changelog, build status, etc"));
		hbox.append(button);
		button.clicked.connect(() => {
			string uri = App.repo_uri;
			if (selected_kernels.size == 1 && selected_kernels[0].is_mainline) uri = selected_kernels[0].page_uri;
			if (!uri_open(uri)) AppGtk.alert(this, _("Unable to launch") + " " + uri);
		});

		btn_uninstall_old = new Button.with_label(_("Uninstall Old"));
		btn_uninstall_old.set_tooltip_text(_("Uninstall everything except:\n* the highest installed version\n* the currently running kernel\n* any kernels that are locked"));
		hbox.append(btn_uninstall_old);
		btn_uninstall_old.clicked.connect(uninstall_old);

		btn_reload = new Button.with_label(_("Reload"));
		btn_reload.set_tooltip_text(_("Delete and reload all cached kernel info\n(the same as \"mainline --delete-cache\")"));
		hbox.append(btn_reload);
		btn_reload.clicked.connect(() => { update_cache(true); });

		button = new Button.with_label(_("Settings"));
		hbox.append(button);
		button.clicked.connect(do_settings);

		button = new Button.with_label(_("About"));
		hbox.append(button);
		button.clicked.connect(do_about);

		button = new Button.with_label(_("Exit"));
		hbox.append(button);
		button.clicked.connect(() => { application.quit(); });
	}

	void do_settings() {
		var old_hide_invalid         = App.hide_invalid;
		var old_hide_unstable        = App.hide_unstable;
		var old_hide_flavors         = App.hide_flavors;
		var old_previous_majors      = App.previous_majors;
		var old_notify_interval_unit  = App.notify_interval_unit;
		var old_notify_interval_value = App.notify_interval_value;
		var old_notify_major         = App.notify_major;
		var old_notify_minor         = App.notify_minor;

		var swin = new SettingsWindow();

		swin.closed.connect(() => {
			App.save_app_config();

			if (App.notify_interval_value == old_notify_interval_value &&
				App.notify_interval_unit  == old_notify_interval_unit  &&
				App.notify_major          == old_notify_major          &&
				App.notify_minor          == old_notify_minor) App.RUN_NOTIFY_SCRIPT = false;

			if (App.hide_invalid    != old_hide_invalid    ||
				App.hide_unstable   != old_hide_unstable   ||
				App.hide_flavors    != old_hide_flavors    ||
				App.previous_majors != old_previous_majors) update_cache();

			App.run_notify_script_if_due();
		});

		swin.present(this);
	}

	void do_about() {
		const string[] developers = {
			"john peter sa <johnppetersa@gmail.com> (Arch Maintainer)",
			"Brian K. White <b.kenyon.w@gmail.com> (Original Author)",
			"Tony George <teejeetech@gmail.com> (Original Author)",
			"shg8@github",
			"cloyce@github",
			"LucasChollet@github"
		};

		const string[] notice_sh = { "Brian K. White (https://github.com/bkw777/notice.sh)" };

		var dialog = new Adw.AboutDialog() {
			application_name = BRANDING_LONGNAME,
			application_icon = BRANDING_SHORTNAME,
			version = BRANDING_VERSION,
			developer_name = BRANDING_AUTHORNAME,
			website = BRANDING_WEBSITE,
			issue_url = BRANDING_WEBSITE + "/issues",
			comments = _("A tool for installing kernel packages\nfrom the Arch Linux Archive"),
			copyright = "Copyright 2015 Tony George (ukuu)\nCopyright %s %s %s".printf(BRANDING_COPYRIGHT, BRANDING_AUTHORNAME, BRANDING_SHORTNAME),
			license_type = Gtk.License.GPL_3_0,
			debug_info = "Kernel: %s\nArch: %s".printf(LinuxKernel.RUNNING_KERNEL, LinuxKernel.NATIVE_ARCH)
		};
		dialog.set_developers(developers);

		
		if (TRANSLATORS != null) {
			dialog.translator_credits = TRANSLATORS.replace("> ", ">\n");
		}

		dialog.add_acknowledgement_section(_("Inclusions"), notice_sh);

		dialog.present(this);
	}


	void update_cache(bool reload = false) {
		vprint("update_cache(reload=" + reload.to_string() + ")", 3);
		string msg = _("Updating Kernels...");
		set_cursor(cursor_busy);
		updating = true;
		set_button_state();
		set_infobar(msg, updating);
		if (reload) { tm.remove_all(); LinuxKernel.delete_cache(); }
		LinuxKernel.mk_kernel_list(false, (last) => { update_status_line(msg, last); });
	}

	void update_status_line(string message, bool last = false) {
		if (last) {
			GLib.Idle.add(() => {
				tv_refresh();
				set_cursor(null);
				if (App.command == "install") {
					App.command = "";
					do_install(LinuxKernel.vlist_to_klist(App.requested_versions));
				}
				return false;
			});
		}

		GLib.Idle.add(() => {
			if (updating) set_infobar("%s: %s %d/%d".printf(message, App.status_line, App.progress_count, App.progress_total), updating);
			return false;
		});
	}

	void init_infobar() {
		var hbox = new Box(Orientation.HORIZONTAL, SPACING);
		vbox_main.append(hbox);
		lbl_info = new Label("");
		spn_info = new Gtk.Spinner();
		hbox.homogeneous = false;
		hbox.append(lbl_info);
		hbox.append(spn_info);
		lbl_info.use_markup  = true;
		lbl_info.selectable  = false;
		lbl_info.hexpand     = true;
		lbl_info.halign      = Align.START;
		spn_info.spinning    = false;
		spn_info.hexpand     = false;
		spn_info.halign      = Align.END;
	}

	void set_infobar(string? text = null, bool busy = false) {
		string s;
		if (text != null) {
			s = text;
			if (!busy) toast_overlay.add_toast(new Adw.Toast(text));
		}
		else {
			s = _("Running") + " <b>%s</b>".printf(LinuxKernel.kernel_active.version_main);
			if (LinuxKernel.kernel_active.is_mainline) s += " (mainline)"; else s += " (distro)";
			
			int cmp = LinuxKernel.kernel_latest_available.compare_to(LinuxKernel.kernel_active);
			if (cmp > 0) {
				s += " ~ <b>%s</b> ".printf(LinuxKernel.kernel_latest_available.version_main) + _("available");
			} else {
				s += " - <small>" + _("Up to date") + "</small>";
			}

			if (LinuxKernel.kernel_list.size <= 1 && LinuxKernel.kall.size > 1) {
				s += " <span color='orange' size='small'>(" + _("Other versions hidden by filters") + ")</span>";
			}
		}
		lbl_info.set_label(s);
		spn_info.spinning = busy;
	}

	public void do_install(Gee.ArrayList<LinuxKernel> klist) {
		string[] vlist = {};
		if (Main.VERBOSE > 2) {
			foreach (var k in klist) vlist += k.version_main;
			vprint("do_install(" + string.joinv(" ", vlist) + ")");
		}
		if (klist == null || klist.size < 1) return;
		vlist = {};
		foreach (var k in klist) vlist += k.version_main;

		string[] cmd = { get_cli_path(), "--from-gui" };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		cmd += "install";
		cmd += string.joinv(",", vlist);
		set_infobar(_("Installing Kernels..."), true);
		exec_in_term(cmd);
	}

	public void do_uninstall(Gee.ArrayList<LinuxKernel> klist) {
		string[] vlist = {};
		if (Main.VERBOSE > 2) {
			foreach (var k in klist) vlist += k.version_main;
			vprint("do_uninstall(" + string.joinv(" ", vlist) + ")");
		}
		if (klist == null || klist.size < 1) return;
		vlist = {};
		foreach (var k in klist) {
			if (k.is_locked || k.is_running) continue;
			vlist += k.version_main;
		}
		if (vlist.length == 0) return;

		string[] cmd = { get_cli_path(), "--from-gui" };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		cmd += "uninstall";
		cmd += string.joinv(",", vlist);
		set_infobar(_("Uninstalling Kernels..."), true);
		exec_in_term(cmd);
	}

	public void uninstall_old() {
		string[] cmd = { get_cli_path(), "--from-gui" };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		cmd += "uninstall-old";
		set_infobar(_("Uninstalling old kernels..."), true);
		exec_in_term(cmd);
	}

	public void exec_in_term(string[] argv) {
		if (App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) {
			var term = new TerminalWindow.with_parent(this);
			term.cmd_complete.connect(() => { update_cache(); });
			term.execute_cmd(argv);
		} else {
			string[] args = {};
			if (FileUtils.test("/.flatpak-info", FileTest.EXISTS)) {
				args += "flatpak";
				args += "run";
				args += "--command=" + CLI_EXE;
				args += "org.bkw777.mainline";
				for (int i = 1; i < argv.length; i++) args += argv[i];
			} else {
				args = argv;
			}
			var cmd = sanitize_cmd(wrap_host_cmd(App.term_cmd)).printf(string.joinv(" ", args));
			vprint("Executing: " + cmd, 0);
			Posix.system(cmd);
			update_cache();
		}
	}

}
