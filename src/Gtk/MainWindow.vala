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
	Button btn_lock_toggle;
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
	Gtk.Box grid_box;
	Gtk.Box list_box;
	Gee.ArrayList<Gtk.FlowBox> flow_boxes;
	Gee.ArrayList<Gtk.ColumnView> list_views;
	Gee.ArrayList<GLib.ListStore> list_stores;
	Gtk.Stack stack_view;
	Gtk.ToggleButton btn_view_toggle;

	Gtk.SignalListItemFactory factory_kernel;
	Gtk.SignalListItemFactory factory_date;
	Gtk.SignalListItemFactory factory_lock;
	Gtk.SignalListItemFactory factory_status;
	Gtk.SignalListItemFactory factory_notes;

	public MainWindow(Adw.Application app) {
		Object(application: app);

		set_default_size(App.window_width, App.window_height);

		title = BRANDING_LONGNAME;
		icon_name = "mainline";
		cursor_busy = new Gdk.Cursor.from_name("wait", null);

		selected_kernels = new Gee.ArrayList<LinuxKernel>();
		tm = new GLib.ListStore(typeof(LinuxKernel));
		sort_model = new Gtk.SortListModel(tm, null);
		sel_model = new Gtk.MultiSelection(sort_model);
		tv = new Gtk.ColumnView(sel_model);
		tv.hexpand = true;
		tv.vexpand = true;
		tv.valign = Gtk.Align.FILL;

		flow_boxes = new Gee.ArrayList<Gtk.FlowBox>();
		list_views = new Gee.ArrayList<Gtk.ColumnView>();
		list_stores = new Gee.ArrayList<GLib.ListStore>();
		grid_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
		grid_box.valign = Gtk.Align.START;
		grid_box.halign = Gtk.Align.FILL;
		grid_box.hexpand = true;
		grid_box.vexpand = true;

		stack_view = new Gtk.Stack();
		stack_view.hexpand = true;
		stack_view.vexpand = true;

		pix_arch        = load_texture("arch-logo.png");
		pix_mainline    = load_texture("tux.png");
		pix_mainline_rc = load_texture("tux-red.png");

		toolbar_view = new Adw.ToolbarView();
		set_content(toolbar_view);

		header_bar = new Adw.HeaderBar();
		toolbar_view.add_top_bar(header_bar);

		btn_view_toggle = new Gtk.ToggleButton();
		btn_view_toggle.icon_name = "view-list-symbolic";
		btn_view_toggle.tooltip_text = _("Switch View");
		btn_view_toggle.active = (App.view_mode == 1);
		header_bar.pack_end(btn_view_toggle);
		btn_view_toggle.toggled.connect(on_view_toggled);

		toast_overlay = new Adw.ToastOverlay();
		toolbar_view.set_content(toast_overlay);

		vbox_main = new Box(Orientation.VERTICAL, 0);
		vbox_main.hexpand = true;
		vbox_main.vexpand = true;
		vbox_main.valign = Gtk.Align.FILL;
		vbox_main.halign = Gtk.Align.FILL;
		toast_overlay.set_child(vbox_main);

		init_styles();
		init_ui();
		update_cache();
	}

	void init_styles() {
		var provider = new Gtk.CssProvider();
		string css = """
			flowboxchild {
				border-radius: 12px;
				padding: 0;
				margin: 0;
			}
			flowboxchild:selected {
				background-color: transparent;
				outline: none;
			}
			flowboxchild:selected .card {
				background-color: @accent_bg_color;
				color: @accent_fg_color;
				box-shadow: 0 0 0 2px @accent_bg_color;
			}
			.card {
				border-radius: 12px;
				transition: all 150ms ease-in-out;
			}
			flowboxchild:hover .card {
				background-color: alpha(@accent_color, 0.05);
			}
			flowboxchild:selected:hover .card {
				background-color: @accent_bg_color;
			}
			/* Estilo para a Lista */
			columnview {
				background-color: transparent;
			}
			columnview header, columnview header button {
				margin-left: 8px;
				margin-right: 8px;
				opacity: 0.7;
				font-weight: bold;
			}
			columnview row {
				padding: 10px 12px;
				border-radius: 12px;
				transition: all 150ms ease-in-out;
				border: 1px solid transparent;
			}
			columnview row:hover {
				background-color: alpha(@accent_color, 0.08);
				border: 1px solid alpha(@accent_color, 0.15);
			}
			columnview row:selected {
				background-color: @accent_bg_color;
				color: @accent_fg_color;
			}
			columnview row:selected:hover {
				background-color: @accent_bg_color;
			}
			columnview row Label {
			}
			.success {
				color: @success_color;
				font-weight: bold;
			}
			.accent {
				color: @accent_color;
			}
			.bold {
				font-weight: bold;
			}
			.version-text {
				font-size: 15px;
				font-weight: 800;
			}
			.sub-text {
				font-size: 12px;
			}
			.series-title {
				font-weight: 800;
				font-size: 1.2rem;
				color: @accent_color;
				margin-top: 16px;
				margin-bottom: 2px;
			}
			.notes-editable {
				background-color: alpha(@window_fg_color, 0.05);
				border-radius: 8px;
				padding: 4px 8px;
				min-height: 30px;
				color: alpha(@window_fg_color, 0.8);
				transition: all 150ms ease-in-out;
			}
			.notes-editable:hover {
				background-color: alpha(@window_fg_color, 0.1);
				color: @window_fg_color;
			}
			columnview row:selected .notes-editable {
				background-color: alpha(@accent_fg_color, 0.15);
				color: @accent_fg_color;
			}
			.notes-editable entry,
			.notes-editable entry text {
				background-color: transparent;
				background-image: none;
				border: none;
				box-shadow: none;
			}
			.italic {
				font-style: italic;
			}
		""";
		provider.load_from_string(css);
		// Use a custom binding to bypass Vala's deprecation warning for global CSS providers
		apply_global_styles(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
	}

	[CCode (cname = "gtk_style_context_add_provider_for_display")]
	public static extern void apply_global_styles (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

	void init_ui() {
		init_treeview();
		init_actions();
		init_infobar();
	}

	void init_treeview() {
		var split_view = new Adw.OverlaySplitView();
		split_view.hexpand = true;
		split_view.vexpand = true;
		split_view.sidebar_position = Gtk.PackType.END;
		split_view.min_sidebar_width = 180; // Reasonable width for a sidebar

		vbox_main.append(split_view);
		
		hbox_list = new Box(Orientation.VERTICAL, SPACING);
		hbox_list.add_css_class("background");
		split_view.sidebar = hbox_list;

		list_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
		list_box.hexpand = true;
		list_box.vexpand = true;
		list_box.valign = Gtk.Align.START;
		// Removed global margins, let the sections have margins

		init_factories();

		var sw_list = new ScrolledWindow();
		sw_list.hexpand = true;
		sw_list.vexpand = true;
		sw_list.halign = Gtk.Align.FILL;
		sw_list.valign = Gtk.Align.FILL;
		sw_list.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
		sw_list.set_child(list_box);

		var sw_grid = new ScrolledWindow();
		sw_grid.hexpand = true;
		sw_grid.vexpand = true;
		sw_grid.halign = Gtk.Align.FILL;
		sw_grid.valign = Gtk.Align.FILL;
		sw_grid.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
		sw_grid.set_child(grid_box);

		stack_view.add_named(sw_list, "list");
		stack_view.add_named(sw_grid, "large");

		split_view.content = stack_view;

		update_view();
	}

	void init_factories() {
		// ── Kernel column (icon + version label) ────────────────────────
		factory_kernel = new Gtk.SignalListItemFactory();
		factory_kernel.setup.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
			box.margin_start = SPACING;
			box.margin_end   = SPACING;

			var overlay = new Gtk.Overlay();
			overlay.valign = Gtk.Align.CENTER;
			box.append(overlay);
			
			var img_bg = new Gtk.Image.from_icon_name("package-x-generic");
			img_bg.pixel_size = 32;
			img_bg.opacity = 0.8;
			overlay.set_child(img_bg);

			var img_emblem = new Gtk.Image();
			img_emblem.pixel_size = 16;
			img_emblem.halign = Gtk.Align.END;
			img_emblem.valign = Gtk.Align.END;
			overlay.add_overlay(img_emblem);

			var lbl = new Gtk.Label("");
			lbl.ellipsize = Pango.EllipsizeMode.END;
			lbl.xalign    = 0;
			lbl.hexpand   = true;
			box.append(lbl);
			li.set_child(box);
		});
		factory_kernel.bind.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var k   = (LinuxKernel) li.get_item();
			var box = (Gtk.Box) li.get_child();
			var overlay = (Gtk.Overlay) box.get_first_child();
			var img_emblem = (Gtk.Image) overlay.get_last_child();
			var lbl = (Gtk.Label) box.get_last_child();

			Gdk.Texture? p = pix_mainline;
			if (k.is_unstable) p = pix_mainline_rc;
			if (!k.is_mainline) p = pix_arch;

			if (p != null) {
				img_emblem.set_from_paintable(p);
			} else {
				if (k.is_mainline) img_emblem.set_from_icon_name("linux-symbolic");
				else img_emblem.set_from_icon_name("operating-system-symbolic");
			}
			lbl.set_label(k.version_main);
			lbl.add_css_class("bold");
			box.set_tooltip_text(k.tooltip_text());
		});

		// ── Date column ──────────────────────────────────────────────────
		factory_date = new Gtk.SignalListItemFactory();
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

		// ── Lock column (checkbox toggle) ────────────────────────────────
		factory_lock = new Gtk.SignalListItemFactory();
		factory_lock.setup.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var cb = new Gtk.CheckButton();
			cb.halign = Gtk.Align.CENTER;
			li.set_child(cb);
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
			var li  = (Gtk.ListItem) obj;
			var k   = (LinuxKernel) li.get_item();
			var cb  = (Gtk.CheckButton) li.get_child();
			is_binding = true;
			cb.active = k.is_locked;
			is_binding = false;
		});

		// ── Status column ────────────────────────────────────────────────
		factory_status = new Gtk.SignalListItemFactory();
		factory_status.setup.connect((obj) => {
			var li  = (Gtk.ListItem) obj;
			var lbl = new Gtk.Label("");
			lbl.xalign    = 0;
			lbl.valign    = Gtk.Align.CENTER;
			lbl.ellipsize = Pango.EllipsizeMode.END;
			lbl.margin_start = SPACING;
			lbl.margin_end   = SPACING;
			li.set_child(lbl);
		});
		factory_status.bind.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var k  = (LinuxKernel) li.get_item();
			var lbl = (Gtk.Label) li.get_child();
			lbl.label = k.status;
			lbl.remove_css_class("success");
			lbl.remove_css_class("accent");
			if (k.is_running) lbl.add_css_class("success");
			else if (k.is_installed) lbl.add_css_class("accent");
		});

		// ── Notes column (inline editable) ──────────────────────────────
		factory_notes = new Gtk.SignalListItemFactory();
		factory_notes.setup.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var el = new Gtk.EditableLabel("");
			el.valign  = Gtk.Align.CENTER;
			el.margin_start = SPACING;
			el.margin_end   = SPACING + 8; // Extra padding to avoid clipping
			el.add_css_class("notes-editable");
			el.set_tooltip_text(_("Click to add or edit a note"));
			li.set_child(el);
			el.notify["editing"].connect(() => {
				if (!el.editing) {
					var k = li.get_item() as LinuxKernel;
					if (k != null) {
						var t_new = el.text.strip();
						if (k.notes.strip() != t_new) k.set_notes(t_new);
					}
				}
			});
		});
		factory_notes.bind.connect((obj) => {
			var li = (Gtk.ListItem) obj;
			var k  = (LinuxKernel) li.get_item();
			var el = (Gtk.EditableLabel) li.get_child();
			el.text = k.notes;
		});
	}

	void populate_columns(Gtk.ColumnView view) {
		var col_kernel = new Gtk.ColumnViewColumn(_("Kernel"), factory_kernel);
		col_kernel.resizable  = true;
		col_kernel.expand     = true;
		col_kernel.fixed_width = 200;
		col_kernel.sorter = new Gtk.CustomSorter((a, b) => {
			return ((LinuxKernel) a).compare_to((LinuxKernel) b);
		});
		view.append_column(col_kernel);

		var col_date = new Gtk.ColumnViewColumn(_("Date"), factory_date);
		col_date.resizable = true;
		col_date.fixed_width = 120;
		view.append_column(col_date);

		var col_lock = new Gtk.ColumnViewColumn(_("Lock"), factory_lock);
		view.append_column(col_lock);

		var col_status = new Gtk.ColumnViewColumn(_("Status"), factory_status);
		col_status.resizable = true;
		col_status.fixed_width = 120;
		view.append_column(col_status);

		var col_notes = new Gtk.ColumnViewColumn(_("Notes"), factory_notes);
		col_notes.resizable   = true;
		col_notes.expand      = true;
		col_notes.fixed_width = 200;
		view.append_column(col_notes);
	}

	void tv_refresh() {
		tm.remove_all();
		
		// Clear Containers
		Gtk.Widget? child;
		while ((child = grid_box.get_first_child()) != null) grid_box.remove(child);
		while ((child = list_box.get_first_child()) != null) list_box.remove(child);
		
		flow_boxes.clear();
		list_views.clear();
		list_stores.clear();

		Gtk.FlowBox current_gv = null;
		Gtk.ColumnView current_tv = null;
		GLib.ListStore current_store = null;
		int current_major = -1;
		int current_minor = -1;

		foreach (var k in LinuxKernel.kernel_list) {
			if (!k.is_installed) {
				if (k.is_invalid  && App.hide_invalid)  continue;
				if (k.is_unstable && App.hide_unstable) continue;
				if (k.flavor != "generic" && App.hide_flavors) continue;
			}
			tm.append(k);
			
			// Group by Major.Minor version
			if (current_gv == null || k.version_major != current_major || k.version_minor != current_minor) {
				current_major = k.version_major;
				current_minor = k.version_minor;

				var section_title = _("Series %d.%d").printf(current_major, current_minor);

				// --- Grid Mode Section ---
				var grid_section = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
				grid_section.margin_start = 16;
				grid_section.margin_end = 16;
				
				var grid_lbl = new Gtk.Label(section_title);
				grid_lbl.halign = Gtk.Align.START;
				grid_lbl.add_css_class("series-title");
				
				var grid_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
				grid_sep.margin_bottom = 8;
				
				current_gv = new Gtk.FlowBox();
				current_gv.set_selection_mode(Gtk.SelectionMode.SINGLE);
				current_gv.activate_on_single_click = true;
				current_gv.column_spacing = 4;
				current_gv.row_spacing = 4;
				current_gv.valign = Gtk.Align.START;
				current_gv.halign = Gtk.Align.START;
				current_gv.hexpand = true;
				current_gv.max_children_per_line = 20;
				current_gv.margin_top = current_gv.margin_bottom = current_gv.margin_start = current_gv.margin_end = 0;
				
				var captured_gv = current_gv;
				captured_gv.selected_children_changed.connect((box) => {
					if (is_binding) return;
					var selected_list = box.get_selected_children();
					if (selected_list != null && selected_list.length() > 0) {
						is_binding = true;
						foreach (var other_gv in flow_boxes) if (other_gv != box) other_gv.unselect_all();
						foreach (var other_tv in list_views) other_tv.get_model().unselect_all();
						is_binding = false;
					}
					on_gv_selection_changed();
				});
				captured_gv.child_activated.connect((card_child) => { 
					captured_gv.select_child(card_child);
					set_button_state(); 
				});
				flow_boxes.add(captured_gv);

				grid_section.append(grid_lbl);
				grid_section.append(grid_sep);
				grid_section.append(captured_gv);
				grid_box.append(grid_section);

				// --- List Mode Section ---
				var list_section = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
				list_section.margin_start = 16;
				list_section.margin_end = 16;
				
				var list_lbl = new Gtk.Label(section_title);
				list_lbl.halign = Gtk.Align.START;
				list_lbl.add_css_class("series-title");

				var list_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
				list_sep.margin_bottom = 8;

				current_store = new GLib.ListStore(typeof(LinuxKernel));
				var sort_m = new Gtk.SortListModel(current_store, null);
				var sel_m = new Gtk.MultiSelection(sort_m);
				current_tv = new Gtk.ColumnView(sel_m);
				current_tv.hexpand = true;
				current_tv.vexpand = false;
				current_tv.valign = Gtk.Align.START;
				current_tv.add_css_class("background");

				populate_columns(current_tv);
				sort_m.sorter = current_tv.sorter;
				
				list_views.add(current_tv);
				list_stores.add(current_store);

				var captured_tv = current_tv;
				sel_m.selection_changed.connect((position, n_items) => {
					if (is_binding) return;
					is_binding = true;
					foreach (var other_gv in flow_boxes) other_gv.unselect_all();
					foreach (var other_tv in list_views) if (other_tv != captured_tv) other_tv.get_model().unselect_all();
					is_binding = false;
					tv_selection_changed();
				});

				list_section.append(list_lbl);
				list_section.append(list_sep);
				list_section.append(current_tv);
				list_box.append(list_section);
			}

			// Add to Models
			var card = create_card(k);
			current_gv.insert(card, -1);
			current_store.append(k);
		}

		selected_kernels.clear();
		updating = false;
		set_infobar();
		set_button_state();
	}

	Gtk.Widget create_card(LinuxKernel k) {
		var card = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		card.add_css_class("card");
		card.width_request = 160;
		card.height_request = 160;
		card.halign = Gtk.Align.FILL;
		card.valign = Gtk.Align.FILL;
		card.set_data<LinuxKernel>("kernel", k);

		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
		box.margin_top = box.margin_bottom = box.margin_start = box.margin_end = 6;
		box.vexpand = true;
		box.hexpand = true;
		box.valign = Gtk.Align.CENTER;
		card.append(box);

		var overlay = new Gtk.Overlay();
		overlay.halign = Gtk.Align.CENTER;
		box.append(overlay);
		
		var img_bg = new Gtk.Image.from_icon_name("package-x-generic");
		img_bg.pixel_size = 96;
		img_bg.opacity = 0.9;
		overlay.set_child(img_bg);

		var img_emblem = new Gtk.Image();
		img_emblem.pixel_size = 40;
		img_emblem.halign = Gtk.Align.END;
		img_emblem.valign = Gtk.Align.END;
		img_emblem.margin_bottom = 2;
		img_emblem.margin_end = 2;
		overlay.add_overlay(img_emblem);
		
		Gdk.Texture? p = pix_mainline;
		if (k.is_unstable) p = pix_mainline_rc;
		if (!k.is_mainline) p = pix_arch;

		if (p != null) {
			img_emblem.set_from_paintable(p);
		} else {
			if (k.is_mainline) img_emblem.set_from_icon_name("linux-symbolic");
			else img_emblem.set_from_icon_name("operating-system-symbolic");
		}

		var lbl_version = new Gtk.Label(k.version_main);
		lbl_version.add_css_class("version-text");
		lbl_version.ellipsize = Pango.EllipsizeMode.END;
		lbl_version.halign = Gtk.Align.CENTER;
		box.append(lbl_version);

		var lbl_date = new Gtk.Label(k.release_date);
		lbl_date.add_css_class("sub-text");
		lbl_date.opacity = 0.6;
		lbl_date.ellipsize = Pango.EllipsizeMode.END;
		lbl_date.halign = Gtk.Align.CENTER;
		box.append(lbl_date);

		var lbl_status = new Gtk.Label(k.status);
		lbl_status.add_css_class("sub-text");
		lbl_status.opacity = 0.7;
		if (k.is_running) {
			lbl_status.add_css_class("success");
			lbl_status.opacity = 1.0;
		}
		lbl_status.ellipsize = Pango.EllipsizeMode.END;
		lbl_status.halign = Gtk.Align.CENTER;
		box.append(lbl_status);

		if (k.is_locked) {
			var lock_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
			lock_box.halign = Gtk.Align.CENTER;
			lock_box.margin_top = 2;
			var lock_icon = new Gtk.Image.from_icon_name("changes-prevent-symbolic");
			lock_icon.pixel_size = 12;
			var lock_lbl = new Gtk.Label(_("Locked"));
			lock_lbl.add_css_class("sub-text");
			lock_box.append(lock_icon);
			lock_box.append(lock_lbl);
			box.append(lock_box);
		}

		if (k.notes != "") {
			var lbl_notes = new Gtk.Label(k.notes);
			lbl_notes.add_css_class("sub-text");
			lbl_notes.add_css_class("italic");
			lbl_notes.opacity = 0.6;
			lbl_notes.ellipsize = Pango.EllipsizeMode.END;
			lbl_notes.halign = Gtk.Align.CENTER;
			lbl_notes.margin_top = 4;
			box.append(lbl_notes);
		}
		
		card.set_tooltip_text(k.tooltip_text());

		return card;
	}

	void on_gv_selection_changed() {
		if (is_binding) return;
		is_binding = true;
		
		// Synchronize FlowBox selection to selected_kernels
		selected_kernels.clear();
		foreach (var current_gv in flow_boxes) {
			current_gv.selected_foreach((box, child) => {
				var card = child.get_child() as Gtk.Box;
				if (card != null) {
					var k = card.get_data<LinuxKernel>("kernel");
					if (k != null) selected_kernels.add(k);
				}
			});
		}

		// Sync to List Views
		foreach (var view in list_views) {
			var selection = view.get_model() as Gtk.MultiSelection;
			if (selection == null) continue;
			selection.unselect_all();
			var model = selection.get_model();
			uint n = model.get_n_items();
			for (uint i = 0; i < n; i++) {
				var k = model.get_item(i) as LinuxKernel;
				if (k != null && selected_kernels.contains(k)) {
					selection.select_item(i, false);
				}
			}
		}
		
		set_button_state();
		is_binding = false;
	}

	void on_view_toggled() {
		App.view_mode = btn_view_toggle.active ? 1 : 0;
		App.save_app_config();
		update_view();
	}

	void update_view() {
		if (App.view_mode == 1) {
			stack_view.visible_child_name = "large";
			btn_view_toggle.icon_name = "view-grid-symbolic";
		} else {
			stack_view.visible_child_name = "list";
			btn_view_toggle.icon_name = "view-list-symbolic";
		}
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
		if (is_binding) return;
		is_binding = true;

		selected_kernels.clear();
		foreach (var view in list_views) {
			var selection = view.get_model() as Gtk.MultiSelection;
			if (selection == null) continue;
			uint n = selection.get_n_items();
			for (uint i = 0; i < n; i++) {
				if (selection.is_selected(i)) {
					var k = selection.get_item(i) as LinuxKernel;
					if (k != null) selected_kernels.add(k);
				}
			}
		}

		// Sync to Grid
		foreach (var current_gv in flow_boxes) {
			current_gv.unselect_all();
			Gtk.Widget? child = current_gv.get_first_child();
			while (child != null) {
				var flow_child = child as Gtk.FlowBoxChild;
				if (flow_child != null) {
					var card = flow_child.get_child() as Gtk.Box;
					if (card != null) {
						var k = card.get_data<LinuxKernel>("kernel");
						if (k != null && selected_kernels.contains(k)) {
							current_gv.select_child(flow_child);
						}
					}
				}
				child = child.get_next_sibling();
			}
		}

		set_button_state();
		is_binding = false;
	}

	void set_button_state() {
		btn_install.sensitive   = false;
		btn_uninstall.sensitive = false;

		if (updating) {
			btn_uninstall_old.sensitive = false;
			btn_reload.sensitive        = false;
			if (btn_lock_toggle != null) btn_lock_toggle.sensitive = false;
			return;
		}

		btn_uninstall_old.sensitive = true;
		btn_reload.sensitive        = true;
		if (btn_lock_toggle != null) btn_lock_toggle.sensitive = selected_kernels.size > 0;

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

		var sidebar = new Box(Orientation.VERTICAL, SPACING);
		sidebar.margin_top = sidebar.margin_bottom = sidebar.margin_start = sidebar.margin_end = 12;
		hbox_list.append(sidebar);

		btn_install = new Button();
		var bc_install = new Adw.ButtonContent();
		bc_install.label = _("Install");
		bc_install.icon_name = "system-software-install-symbolic";
		btn_install.child = bc_install;
		btn_install.add_css_class("suggested-action");
		sidebar.append(btn_install);
		btn_install.clicked.connect(() => { do_install(selected_kernels); });

		btn_uninstall = new Button();
		var bc_uninstall = new Adw.ButtonContent();
		bc_uninstall.label = _("Uninstall");
		bc_uninstall.icon_name = "user-trash-symbolic";
		btn_uninstall.child = bc_uninstall;
		btn_uninstall.add_css_class("destructive-action");
		sidebar.append(btn_uninstall);
		btn_uninstall.clicked.connect(() => { do_uninstall(selected_kernels); });

		btn_lock_toggle = new Button();
		var bc_lock = new Adw.ButtonContent();
		bc_lock.label = _("Lock / Unlock");
		bc_lock.icon_name = "changes-prevent-symbolic";
		btn_lock_toggle.child = bc_lock;
		sidebar.append(btn_lock_toggle);
		btn_lock_toggle.clicked.connect(() => {
			foreach (var k in selected_kernels) {
				k.set_locked(!k.is_locked);
			}
			tv_refresh();
			set_button_state();
		});

		button = new Button.with_label("Repo");
		button.set_tooltip_text(_("Changelog, build status, etc"));
		sidebar.append(button);
		button.clicked.connect(() => {
			string uri = App.repo_uri;
			if (selected_kernels.size == 1 && selected_kernels[0].is_mainline) uri = selected_kernels[0].page_uri;
			if (!uri_open(uri)) AppGtk.alert(this, _("Unable to launch") + " " + uri);
		});

		btn_uninstall_old = new Button.with_label(_("Uninstall Old"));
		btn_uninstall_old.set_tooltip_text(_("Uninstall everything except:\n* the highest installed version\n* the currently running kernel\n* any kernels that are locked"));
		sidebar.append(btn_uninstall_old);
		btn_uninstall_old.clicked.connect(uninstall_old);

		btn_reload = new Button.with_label(_("Reload"));
		btn_reload.set_tooltip_text(_("Delete and reload all cached kernel info\n(the same as \"mainline --delete-cache\")"));
		sidebar.append(btn_reload);
		btn_reload.clicked.connect(() => { update_cache(true); });

		button = new Button.with_label(_("Settings"));
		sidebar.append(button);
		button.clicked.connect(do_settings);

		button = new Button.with_label(_("About"));
		sidebar.append(button);
		button.clicked.connect(do_about);

		button = new Button.with_label(_("Exit"));
		sidebar.append(button);
		button.clicked.connect(() => { application.quit(); });
	}

	void do_settings() {
		// capture some settings before to detect if they change
		var old_hide_invalid = App.hide_invalid;
		var old_hide_unstable = App.hide_unstable;
		var old_hide_flavors = App.hide_flavors;
		var old_previous_majors = App.previous_majors;

		var swin = new SettingsWindow();
		swin.unrealize.connect(() => {
			App.save_app_config();
			// if the selection set changed, then update cache
			if (App.hide_invalid != old_hide_invalid ||
				App.hide_unstable != old_hide_unstable ||
				App.hide_flavors != old_hide_flavors ||
				App.previous_majors != old_previous_majors) update_cache();
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

		var dialog = new Adw.AboutDialog() {
			application_name = BRANDING_LONGNAME,
			application_icon = BRANDING_SHORTNAME,
			version = BRANDING_VERSION,
			comments = _("A tool for installing kernel packages\nfrom the Arch Linux Archive"),
			website = BRANDING_WEBSITE,
			license_type = Gtk.License.GPL_3_0,
			translator_credits = TRANSLATORS
		};
		dialog.set_developers(developers);
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
		hbox.append(lbl_info);
		hbox.append(spn_info);
		lbl_info.hexpand     = true;
		lbl_info.halign      = Align.START;
		spn_info.spinning    = false;
	}

	void set_infobar(string? text = null, bool busy = false) {
		string s;
		if (text != null) s = text;
		else s = _("Running") + " <b>%s</b>".printf(LinuxKernel.kernel_active.version_main);
		lbl_info.set_label(s);
		lbl_info.use_markup = true;
		spn_info.spinning = busy;
	}

	public void do_install(Gee.ArrayList<LinuxKernel> klist) {
		if (klist == null || klist.size < 1) return;
		string[] vlist = {};
		foreach (var k in klist) vlist += k.version_main;

		string[] cmd = { get_cli_path(), "--from-gui", "install", string.joinv(",", vlist) };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		set_infobar(_("Installing Kernels..."), true);
		exec_in_term(cmd);
	}

	public void do_uninstall(Gee.ArrayList<LinuxKernel> klist) {
		if (klist == null || klist.size < 1) return;
		string[] vlist = {};
		foreach (var k in klist) {
			if (k.is_locked || k.is_running) continue;
			vlist += k.version_main;
		}
		if (vlist.length == 0) return;

		string[] cmd = { get_cli_path(), "--from-gui", "uninstall", string.joinv(",", vlist) };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
		set_infobar(_("Uninstalling Kernels..."), true);
		exec_in_term(cmd);
	}

	public void uninstall_old() {
		string[] cmd = { get_cli_path(), "--from-gui", "uninstall-old" };
		if (!App.term_cmd.has_suffix(DEFAULT_TERM_CMDS[0])) cmd += "--pause";
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
