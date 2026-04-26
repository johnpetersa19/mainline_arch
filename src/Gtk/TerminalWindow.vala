using l_misc;
using Gtk;
using Adw;

public class TerminalWindow : Adw.Window {

	const double FONT_SCALE_MIN = 0.25;
	const double FONT_SCALE_MAX = 4.0;
	const double FONT_SCALE_STEP = 0.125;

	Vte.Terminal term;
	Pid child_pid = -1;
	Gtk.Window? parent_win = null;
	Gtk.Button btn_close;
	Gtk.Button btn_cancel;

	public bool cancelled = false;
	public bool is_running = false;

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

		set_default_size(App.term_width,App.term_height);

		title = BRANDING_LONGNAME;

		// vbox_main ---------------

		var vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		set_content(vbox_main);

		// terminal ----------------------

		term = new Vte.Terminal();
		term.hexpand = true;
		term.vexpand = true;
		term.font_scale = App.term_font_scale;

		var display = term.get_display();
		var clipboard = display.get_clipboard();

		var scroll_win = new Gtk.ScrolledWindow();
		scroll_win.set_child(term);
		scroll_win.hexpand = true;
		scroll_win.vexpand = true;
		scroll_win.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		scroll_win.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		vbox_main.append(scroll_win);

		term.input_enabled = true;
		term.backspace_binding = Vte.EraseBinding.AUTO;
		term.cursor_blink_mode = Vte.CursorBlinkMode.SYSTEM;
		term.cursor_shape = Vte.CursorShape.UNDERLINE;

		term.scroll_on_keystroke = true;
		term.scroll_on_output = true;
		term.scrollback_lines = -1;

		// rude blasting away the clipboard instead of using a context menu
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

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox.homogeneous = true;
		vbox_main.append(hbox);

		// copy the entire output & scrollback to clipboard
		var btn_copy = new Gtk.Button.with_label(_("Copy"));
		btn_copy.clicked.connect(()=>{
			long output_end_col, output_end_row;
			size_t len;
			term.get_cursor_position(out output_end_col, out output_end_row);
			string? buf = term.get_text_range_format(Vte.Format.TEXT, 0, 0, output_end_row, -1, out len);
			clipboard.set_text(buf);
			AppGtk.alert(this, "copied "+output_end_row.to_string()+" lines to clipboard");
		});
		btn_copy.set_tooltip_text(_("Copies the entire output buffer, including scrollback, to the clipboard."));
		hbox.append(btn_copy);

		var label = new Gtk.Label("");
		hbox.append(label);

		// btn_cancel
		btn_cancel = new Gtk.Button.with_label(_("Cancel"));
		btn_cancel.clicked.connect(()=>{
			cancelled = true;
			if (child_pid > 1) Posix.kill(child_pid, Posix.Signal.HUP);
		});
		hbox.append(btn_cancel);

		// btn_close
		btn_close = new Gtk.Button.with_label(_("Close"));
		btn_close.clicked.connect(()=>{
			App.term_width = get_width();
			App.term_height = get_height();
			App.term_font_scale = term.font_scale;
			close();
		});
		hbox.append(btn_close);

		label = new Gtk.Label("");
		hbox.append(label);

		// font +/-
		var fhbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		var btn_minus = new Gtk.Button.with_label("-");
		btn_minus.clicked.connect(dec_font_scale);
		fhbox.append(btn_minus);
		var btn_zero = new Gtk.Button.with_label("0");
		btn_zero.clicked.connect(() => { term.font_scale = 1; });
		fhbox.append(btn_zero);
		var btn_plus = new Gtk.Button.with_label("+");
		btn_plus.clicked.connect(inc_font_scale);
		fhbox.append(btn_plus);
		hbox.append(fhbox);
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
		cmd_complete.connect(()=>{ present(); allow_close(true); });
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
		close_request.connect(() => { return !allow; });
		deletable = allow;
		btn_close.sensitive = allow;
		btn_close.visible = allow;
		btn_cancel.sensitive = !allow;
		btn_cancel.visible = !allow;
	}

}
