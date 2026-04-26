using Gtk;
using Adw;
using l_misc;

public class SettingsWindow : Adw.PreferencesDialog {

	public SettingsWindow() {
		Object(title: BRANDING_LONGNAME + " " + _("Configuration"));

		// Page 1: Filters
		var page_filters = new Adw.PreferencesPage();
		page_filters.title = _("Filters");
		page_filters.icon_name = "view-filter-symbolic";
		add(page_filters);

		var group_filters = new Adw.PreferencesGroup();
		group_filters.title = _("General Filters");
		page_filters.add(group_filters);

		// Hide RC/Unstable
		var row_hide_unstable = new Adw.SwitchRow();
		row_hide_unstable.title = _("Hide RC and unstable releases");
		row_hide_unstable.active = App.hide_unstable;
		row_hide_unstable.notify["active"].connect(() => { App.hide_unstable = row_hide_unstable.active; });
		group_filters.add(row_hide_unstable);

		// Hide Invalid
		var row_hide_invalid = new Adw.SwitchRow();
		row_hide_invalid.title = _("Hide failed or incomplete builds");
		row_hide_invalid.subtitle = _("Only show builds compatible with your architecture (%s)").printf(LinuxKernel.NATIVE_ARCH);
		row_hide_invalid.active = App.hide_invalid;
		row_hide_invalid.notify["active"].connect(() => { App.hide_invalid = row_hide_invalid.active; });
		group_filters.add(row_hide_invalid);

		// Hide Flavors
		var row_hide_flavors = new Adw.SwitchRow();
		row_hide_flavors.title = _("Hide flavors other than %s").printf("\"generic\"");
		row_hide_flavors.active = App.hide_flavors;
		row_hide_flavors.notify["active"].connect(() => { App.hide_flavors = row_hide_flavors.active; });
		group_filters.add(row_hide_flavors);

		// Prior major versions
		var row_prior_majors = new Adw.ActionRow();
		row_prior_majors.title = _("Show prior major versions");
		row_prior_majors.subtitle = _("(-1 = all)");
		var spin_prior = new Gtk.SpinButton.with_range(-1, 100, 1);
		spin_prior.value = App.previous_majors;
		spin_prior.valign = Gtk.Align.CENTER;
		spin_prior.changed.connect(() => { App.previous_majors = (int)spin_prior.value; });
		row_prior_majors.add_suffix(spin_prior);
		group_filters.add(row_prior_majors);

		// Page 2: Notifications
		var page_notifications = new Adw.PreferencesPage();
		page_notifications.title = _("Notifications");
		page_notifications.icon_name = "preferences-desktop-notification-symbolic";
		add(page_notifications);

		var group_notify = new Adw.PreferencesGroup();
		group_notify.title = _("Notification Settings");
		page_notifications.add(group_notify);

		var row_notify_major = new Adw.SwitchRow();
		row_notify_major.title = _("Notify if a major release is available");
		row_notify_major.active = App.notify_major;
		row_notify_major.notify["active"].connect(() => { App.notify_major = row_notify_major.active; });
		group_notify.add(row_notify_major);

		var row_notify_minor = new Adw.SwitchRow();
		row_notify_minor.title = _("Notify if a minor release is available");
		row_notify_minor.active = App.notify_minor;
		row_notify_minor.notify["active"].connect(() => { App.notify_minor = row_notify_minor.active; });
		group_notify.add(row_notify_minor);

		// Check interval
		var row_interval = new Adw.ActionRow();
		row_interval.title = _("Check every");
		var spin_interval = new Gtk.SpinButton.with_range(1, 100, 1);
		spin_interval.value = App.notify_interval_value;
		spin_interval.valign = Gtk.Align.CENTER;
		spin_interval.changed.connect(() => { App.notify_interval_value = (int)spin_interval.value; });
		row_interval.add_suffix(spin_interval);

		// Replace ComboBoxText with DropDown + StringList
		var units_list = new Gtk.StringList(null);
		units_list.append(_("Hours"));
		units_list.append(_("Days"));
		units_list.append(_("Weeks"));
		var combo_units = new Gtk.DropDown(units_list, null);
		combo_units.selected = (uint)App.notify_interval_unit;
		combo_units.valign = Gtk.Align.CENTER;
		combo_units.notify["selected"].connect(() => { App.notify_interval_unit = (int)combo_units.selected; });
		row_interval.add_suffix(combo_units);
		group_notify.add(row_interval);

		// Page 3: Network
		var page_network = new Adw.PreferencesPage();
		page_network.title = _("Network");
		page_network.icon_name = "network-workgroup-symbolic";
		add(page_network);

		var group_network = new Adw.PreferencesGroup();
		group_network.title = GLib.Markup.escape_text(_("Download & Connection"));
		page_network.add(group_network);

		// Timeout
		var row_timeout = new Adw.ActionRow();
		row_timeout.title = _("Connection Timeout (seconds)");
		var spin_timeout = new Gtk.SpinButton.with_range(1, 600, 1);
		spin_timeout.value = App.connect_timeout_seconds;
		spin_timeout.valign = Gtk.Align.CENTER;
		spin_timeout.changed.connect(() => { App.connect_timeout_seconds = (int)spin_timeout.value; });
		row_timeout.add_suffix(spin_timeout);
		group_network.add(row_timeout);

		// Concurrent Downloads
		var row_concurrent = new Adw.ActionRow();
		row_concurrent.title = _("Concurrent Downloads");
		var spin_concurrent = new Gtk.SpinButton.with_range(1, 25, 1);
		spin_concurrent.value = App.concurrent_downloads;
		spin_concurrent.valign = Gtk.Align.CENTER;
		spin_concurrent.changed.connect(() => { App.concurrent_downloads = (int)spin_concurrent.value; });
		row_concurrent.add_suffix(spin_concurrent);
		group_network.add(row_concurrent);

		// Checksums
		var row_checksums = new Adw.SwitchRow();
		row_checksums.title = _("Verify Checksums");
		row_checksums.active = App.verify_checksums;
		row_checksums.notify["active"].connect(() => { App.verify_checksums = row_checksums.active; });
		group_network.add(row_checksums);

		// Page 4: Advanced
		var page_advanced = new Adw.PreferencesPage();
		page_advanced.title = _("Advanced");
		page_advanced.icon_name = "preferences-system-symbolic";
		add(page_advanced);

		var group_urls = new Adw.PreferencesGroup();
		group_urls.title = GLib.Markup.escape_text(_("URLs & User Agent"));
		page_advanced.add(group_urls);

		// PPA URL
		var row_ppa = new Adw.EntryRow();
		row_ppa.title = _("Mainline-PPA URL");
		row_ppa.text = App.ppa_uri;
		row_ppa.notify["text"].connect(() => { App.ppa_uri = row_ppa.text.strip(); });
		group_urls.add(row_ppa);

		// User Agent
		var row_ua = new Adw.EntryRow();
		row_ua.title = _("User Agent String");
		row_ua.text = App.user_agent;
		row_ua.notify["text"].connect(() => { App.user_agent = row_ua.text.strip(); });
		group_urls.add(row_ua);

		var group_commands = new Adw.PreferencesGroup();
		group_commands.title = _("External Commands");
		page_advanced.add(group_commands);

		// Auth Command
		var row_auth = new Adw.EntryRow();
		row_auth.title = _("Superuser Authorization");
		row_auth.text = App.auth_cmd;
		row_auth.notify["text"].connect(() => { App.auth_cmd = row_auth.text.strip(); });
		group_commands.add(row_auth);

		// Terminal Command
		var row_term = new Adw.EntryRow();
		row_term.title = _("Terminal Window");
		row_term.text = App.term_cmd;
		row_term.notify["text"].connect(() => { App.term_cmd = row_term.text.strip(); });
		group_commands.add(row_term);
	}
}
