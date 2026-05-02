using Gtk;
using Adw;
using l_misc;
using l_exec;

public class TerminalWindow : Adw.Window {

	const double FONT_SCALE_MIN = 0.5;
	const double FONT_SCALE_MAX = 3.0;
	const double FONT_SCALE_STEP = 0.1;

	Vte.Terminal term;
	Pid child_pid = -1;
	Gtk.Window? parent_win = null;
	Gtk.Button btn_cancel;
	Adw.HeaderBar header_bar;

	public bool cancelled = false;
	public bool is_running = false;
	bool can_close = false;

	public signal void cmd_complete();

	public TerminalWindow.with_parent(Gtk.Window? parent) {
		if (parent != null) {
			set_transient_for(parent);
			parent_win = parent;
		}

		init_window();
		allow_close(false);
	}

	public bool cancel_window_close() { return true; }

	public void init_window() {
		set_modal(true);
		set_default_size(800, 500);
		title = BRANDING_LONGNAME;

		this.close_request.connect(() => {
			if (can_close) {
				App.term_width = get_width();
				App.term_height = get_height();
				App.term_font_scale = term.font_scale;
			}
			return !can_close;
		});

		var toolbar_view = new Adw.ToolbarView();
		set_content(toolbar_view);

		// Header Bar
		header_bar = new Adw.HeaderBar();
		toolbar_view.add_top_bar(header_bar);

		// Terminal ----------------------
		term = new Vte.Terminal();
		term.hexpand = true;
		term.vexpand = true;
		term.font_scale = App.term_font_scale;
		
		// Set a nice default font
		var font_desc = Pango.FontDescription.from_string("Monospace 11");
		term.set_font(font_desc);

		var scroll_win = new Gtk.ScrolledWindow();
		scroll_win.set_child(term);
		scroll_win.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		scroll_win.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		toolbar_view.set_content(scroll_win);

		term.input_enabled = true;
		term.backspace_binding = Vte.EraseBinding.AUTO;
		term.cursor_blink_mode = Vte.CursorBlinkMode.ON;
		term.cursor_shape = Vte.CursorShape.BLOCK;

		term.scroll_on_keystroke = true;
		term.scroll_on_output = true;
		term.scrollback_lines = 10000;

		term.selection_changed.connect(() => { term.copy_clipboard_format(Vte.Format.TEXT); });

		// ctrl+scroll to zoom font size
		var scroll_controller = new Gtk.EventControllerScroll(Gtk.EventControllerScrollFlags.VERTICAL);
		scroll_controller.scroll.connect((dx, dy) => {
			var state = scroll_controller.get_current_event_state();
			if ((state & Gdk.ModifierType.CONTROL_MASK) > 0) {
				if (dy > 0) dec_font_scale();
				if (dy < 0) inc_font_scale();
				return true;
			}
			return false;
		});
		term.add_controller(scroll_controller);

		term.grab_focus();

		// Bottom bar buttons
		var bottom_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		bottom_bar.margin_start = bottom_bar.margin_end = bottom_bar.margin_top = bottom_bar.margin_bottom = 12;
		bottom_bar.add_css_class("background");
		toolbar_view.add_bottom_bar(bottom_bar);

		// btn_cancel (Destructive)
		btn_cancel = new Gtk.Button.with_label(_("Cancel"));
		btn_cancel.add_css_class("destructive-action");
		btn_cancel.clicked.connect(()=>{
			cancelled = true;
			if (child_pid > 1) Posix.kill(child_pid, Posix.Signal.HUP);
		});
		bottom_bar.append(btn_cancel);

		var spacer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		spacer.hexpand = true;
		bottom_bar.append(spacer);

		// Utility Box (Copy + Zoom)
		var util_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		bottom_bar.append(util_box);

		// Copy button
		var btn_copy = new Gtk.Button.from_icon_name("edit-copy-symbolic");
		btn_copy.set_tooltip_text(_("Copy all output"));
		btn_copy.clicked.connect(()=>{
			long output_end_col, output_end_row;
			size_t len;
			term.get_cursor_position(out output_end_col, out output_end_row);
			string? buf = term.get_text_range_format(Vte.Format.TEXT, 0, 0, output_end_row, -1, out len);
			var display = term.get_display();
			display.get_clipboard().set_text(buf);
		});
		util_box.append(btn_copy);

		// Zoom buttons
		var zoom_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		zoom_box.add_css_class("linked");
		
		var btn_minus = new Gtk.Button.from_icon_name("zoom-out-symbolic");
		btn_minus.clicked.connect(dec_font_scale);
		zoom_box.append(btn_minus);
		
		var btn_zero = new Gtk.Button.with_label("100%");
		btn_zero.clicked.connect(() => { term.font_scale = 1; });
		zoom_box.append(btn_zero);
		
		var btn_plus = new Gtk.Button.from_icon_name("zoom-in-symbolic");
		btn_plus.clicked.connect(inc_font_scale);
		zoom_box.append(btn_plus);
		
		util_box.append(zoom_box);
	}

	public void inc_font_scale() {
		term.font_scale = (term.font_scale + FONT_SCALE_STEP).clamp(FONT_SCALE_MIN, FONT_SCALE_MAX);
	}

	public void dec_font_scale() {
		term.font_scale = (term.font_scale - FONT_SCALE_STEP).clamp(FONT_SCALE_MIN, FONT_SCALE_MAX);
	}

	void spawn_cb(Vte.Terminal t, Pid p, Error? e) {
		vprint("child_pid="+p.to_string(),4);
		if (p > 1) child_pid = p;
		else child_has_exited(e.code);
		if (e != null) term.feed(e.message.data);
	}

	public void execute_cmd(string[] argv) {
		vprint("TerminalWindow execute_cmd("+string.joinv(" ",argv)+")",3);
		present();
		cmd_complete.connect(()=>{ allow_close(true); });
		term.child_exited.connect(child_has_exited);
		is_running = true;
		term.spawn_async(
			Vte.PtyFlags.DEFAULT,        // pty_flags
			null,                        // working directory
			argv,                        // argv
			null,                        // env
			GLib.SpawnFlags.SEARCH_PATH, // spawn flags
			null,                        // child_setup()
			-1,                          // timeout
			null,                        // cancellable
			spawn_cb                     // spawn callback
		);
	}

	public void child_has_exited(int status) {
		vprint("TerminalWindow child_has_exited("+status.to_string()+")",3);
		is_running = false;
		cmd_complete();
	}

	public void allow_close(bool allow) {
		can_close = allow;
		header_bar.show_start_title_buttons = allow;
		header_bar.show_end_title_buttons = allow;
		
		// Just disable the cancel button instead of hiding it to prevent layout shifts
		btn_cancel.sensitive = !allow;
	}

}
