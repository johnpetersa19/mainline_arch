using l_misc;

namespace l_exec {
	public bool uri_open(string s) {
		bool r = true;
		try { AppInfo.launch_default_for_uri(s,null); }
		catch (Error e) { r = false; vprint(_("Unable to launch")+" "+s,1,stderr); }
		return r;
	}

	// blocking exec with command line string
	public int exec_sync(string cmd, out string? std_out = null, out string? std_err = null) {
		vprint("exec_sync("+cmd+")",3);
		int r = 0;
		string full_cmd = wrap_host_cmd(cmd);
		try { Process.spawn_command_line_sync(full_cmd, out std_out, out std_err); }
		catch (SpawnError e) { r = 1; vprint(e.message,1,stderr); }
		return r;
	}

	// blocking exec with argument array (safer)
	public int exec_sync_argv(string[] argv, out string? std_out = null, out string? std_err = null) {
		vprint("exec_sync_argv("+string.joinv(" ", argv)+")",3);
		int r = 0;
		try {
			Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH, null, out std_out, out std_err, out r);
		} catch (SpawnError e) {
			r = 1;
			vprint(e.message, 1, stderr);
		}
		return r;
	}

	// non-blocking exec with command line string
	public void exec_async(string cmd) {
		vprint("exec_async("+cmd+")",3);
		string full_cmd = wrap_host_cmd(cmd);
		try { Process.spawn_command_line_async(full_cmd); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
	}

	// non-blocking exec with argument array (safer)
	public void exec_async_argv(string[] argv) {
		vprint("exec_async_argv("+string.joinv(" ", argv)+")",3);
		try {
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
		} catch (SpawnError e) {
			vprint(e.message, 1, stderr);
		}
	}
}

