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

	Box vbox_main;
	Box hbox_list;

	Button btn_install;
	Button btn_uninstall;
	Button btn_uninstall_old;
	Button btn_reload;
	Label lbl_info;
	Gtk.Spinner spn_info;
	Gdk.Texture? pix_ubuntu;
	Gdk.Texture? pix_mainline;
	Gdk.Texture? pix_mainline_rc;
	Gdk.Cursor cursor_busy;

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

		try {
			pix_ubuntu    = Gdk.Texture.from_filename(INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/ubuntu-logo.png");
			pix_mainline  = Gdk.Texture.from_filename(INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux.png");
			pix_mainline_rc = Gdk.Texture.from_filename(INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux-red.png");
		} catch (Error e) { vprint(e.message, 1, stderr); }

		vbox_main = new Box(Orientation.VERTICAL, SPACING);
		vbox_main.set_margin_start(SPACING);
		vbox_main.set_margin_end(SPACING);
		vbox_main.set_margin_top(SPACING);
		vbox_main.set_margin_bottom(SPACING);

		set_content(vbox_main);

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
			var pic = new Gtk.Picture();
			pic.can_shrink    = true;
			pic.content_fit   = Gtk.ContentFit.CONTAIN;
			pic.width_request  = 24;
			pic.height_request = 24;
			var lbl = new Gtk.Label("");
			lbl.ellipsize = Pango.EllipsizeMode.END;
			lbl.xalign    = 0;
			lbl.hexpand   = true;
			box.append(pic);
			box.append(lbl);
			li.set_child(box);
		});
		factory_kernel.bind.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var k   = (LinuxKernel) li.get_item();
			var box = (Gtk.Box) li.get_child();
			var pic = (Gtk.Picture) box.get_first_child();
			var lbl = (Gtk.Label) pic.get_next_sibling();
			Gdk.Texture? p = pix_mainline;
			if (k.is_unstable) p = pix_mainline_rc;
			if (!k.is_mainline) p = pix_ubuntu;
			pic.set_paintable(p);
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

		// ── Lock column (checkbox toggle) ────────────────────────────────
		var factory_lock = new Gtk.SignalListItemFactory();
		factory_lock.setup.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var cb = new Gtk.CheckButton();
			cb.halign = Gtk.Align.CENTER;
			li.set_child(cb);
			// connect once; read current item via closure over li
			cb.toggled.connect(() => {
				var k = li.get_item() as LinuxKernel;
				if (k != null && cb.active != k.is_locked) {
					k.set_locked(cb.active);
					// refresh tooltip on kernel column widget
				}
			});
		});
		factory_lock.bind.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var k  = (LinuxKernel) li.get_item();
			var cb = (Gtk.CheckButton) li.get_child();
			// block signal temporarily so bind doesn't trigger toggled
			GLib.SignalHandler.block_by_func(cb, (void*)on_lock_toggled_dummy, cb);
			cb.active = k.is_locked;
			GLib.SignalHandler.unblock_by_func(cb, (void*)on_lock_toggled_dummy, cb);
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

	// Dummy function pointer used only for signal block/unblock by func
	static void on_lock_toggled_dummy() {}

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
			if (k.is_locked || k.is_running) continue;
			if (k.is_installed) btn_uninstall.sensitive = true;
			else if (!k.is_invalid) btn_install.sensitive = true;
		}
	}

	void init_actions() {
		Button button;

		var hbox = new Box(Orientation.VERTICAL, SPACING);
		hbox_list.append(hbox);

		btn_install = new Button.with_label(_("Install"));
		hbox.append(btn_install);
		btn_install.clicked.connect(() => { do_install(selected_kernels); });
		btn_uninstall = new Button.with_label(_("Uninstall"));
		hbox.append(btn_uninstall);
		btn_uninstall.clicked.connect(() => { do_uninstall(selected_kernels); });

		button = new Button.with_label("PPA");
		button.set_tooltip_text(_("Changelog, build status, etc"));
		hbox.append(button);
		button.clicked.connect(() => {
			string uri = App.ppa_uri;
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
		string[] developers = {
			BRANDING_AUTHORNAME + " <" + BRANDING_AUTHOREMAIL + ">",
			"Tony George <teejeetech@gmail.com>",
			"shg8@github",
			"cloyce@github",
			"LucasChollet@github"
		};

		string[] notice_sh = { "Brian K. White (https://github.com/bkw777/notice.sh)" };

		var dialog = new Adw.AboutDialog();
		dialog.application_name = BRANDING_LONGNAME;
		dialog.version = BRANDING_VERSION;
		dialog.developer_name = BRANDING_AUTHORNAME;
		dialog.website = BRANDING_WEBSITE;
		dialog.issue_url = BRANDING_WEBSITE + "/issues";
		dialog.comments = _("A tool for installing kernel packages\nfrom the Ubuntu Mainline Kernels PPA");
		dialog.copyright = "\"ukuu\" 2015 Tony George\n\"" + BRANDING_SHORTNAME + "\" " + BRANDING_COPYRIGHT + " " + BRANDING_AUTHORNAME;
		dialog.license_type = Gtk.License.GPL_3_0;
		dialog.developers = developers;
		
		// Improve translator formatting: replace the spaces between entries with newlines
		if (TRANSLATORS != null) {
			dialog.translator_credits = TRANSLATORS.replace("> ", ">\n");
		}

		dialog.add_acknowledgement_section(_("Inclusions"), notice_sh);

		// Try to load icon from the absolute path if it's not in the theme
		string icon_path = INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux.png";
		if (GLib.FileUtils.test(icon_path, GLib.FileTest.EXISTS)) {
			dialog.application_icon = icon_path;
		} else {
			dialog.application_icon = BRANDING_SHORTNAME;
		}

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
		if (text != null) s = text;
		else {
			s = _("Running") + " <b>%s</b>".printf(LinuxKernel.kernel_active.version_main);
			if (LinuxKernel.kernel_active.is_mainline) s += " (mainline)"; else s += " (ubuntu)";
			if (LinuxKernel.kernel_latest_available.compare_to(LinuxKernel.kernel_latest_installed) > 0)
				s += " ~ <b>%s</b> ".printf(LinuxKernel.kernel_latest_available.version_main) + _("available");
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

		string[] cmd = { BRANDING_SHORTNAME, "--from-gui" };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		cmd += "install";
		cmd += string.joinv(",", vlist);
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
		foreach (var k in klist) vlist += k.version_main;

		string[] cmd = { BRANDING_SHORTNAME, "--from-gui" };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		cmd += "uninstall";
		cmd += string.joinv(",", vlist);
		exec_in_term(cmd);
	}

	public void uninstall_old() {
		string[] cmd = { BRANDING_SHORTNAME, "--from-gui" };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		cmd += "uninstall-old";
		exec_in_term(cmd);
	}

	public void exec_in_term(string[] argv) {
		if (App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) {
			var term = new TerminalWindow.with_parent(this);
			term.cmd_complete.connect(() => { update_cache(); });
			term.execute_cmd(argv);
		} else {
			var cmd = sanitize_cmd(App.term_cmd).printf(string.joinv(" ", argv));
			vprint(cmd, 3);
			Posix.system(cmd);
			update_cache();
		}
	}

}
