
using l_misc;
using l_exec;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {

	public string version = "";      // display version without _flavor
	public string flavor = "";       // generic, lowlatency, lpae, etc
	public string name = "";         // package name
	public string vers = "";         // package version
	public string version_main = ""; // display version with _flavor
	public string page_uri = "";
	public string notes = "";

	public int version_major = -1;
	public int version_minor = -1;
	public int version_micro = -1;
	public int version_rc = -1;
	public string version_extra = "";
	public string version_sort = "";
	public string release_date = "";

	public Gee.HashMap<string,string> pkg_url_list = new Gee.HashMap<string,string>(); // assosciated packages K=filename,V=url
	public Gee.HashMap<string,string> pkg_checksum_list = new Gee.HashMap<string,string>(); // assosciated packages K=filename,V=checksum
	public string[] pkg_list = {}; // associated package names

	public int REPO_DIRS_VER = 0; // 0 = not set, 1 = old single dirs, 2 = new /<arch>/ subdirs
	public string CACHE_KDIR;
	public string CACHED_PAGE;
	public string CHECKSUMS_FILE;
	public string CHECKSUMS_URI;
	public string INVALID_FILE;

	public string DATA_KDIR;
	public string NOTES_FILE;
	public string LOCKED_FILE;

	public bool is_invalid = false;
	public bool is_locked = false;
	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = true;
	public bool is_unstable = false;
	public int64 repo_datetime = -1; // timestamp from the main index
	public string status = ""; // Running, Installed, Invalid, for display only

	// static
	public static string NATIVE_ARCH;
	public static string LINUX_DISTRO;
	public static string RUNNING_KERNEL;
	public static int THRESHOLD_MAJOR = -1;

	public static string MAIN_INDEX_FILE;

	public static LinuxKernel kernel_active;
	public static LinuxKernel kernel_update_major;
	public static LinuxKernel kernel_update_minor;
	public static LinuxKernel kernel_latest_available;
	public static LinuxKernel kernel_latest_installed;
	public static LinuxKernel kernel_oldest_installed;
	public static LinuxKernel kernel_last_stable_repo_dirs_v1;
	public static LinuxKernel kernel_last_unstable_repo_dirs_v1;
	//public static LinuxKernel kernel_last_stable_repo_dirs_v2; // add more if the site changes again
	//public static LinuxKernel kernel_last_unstable_repo_dirs_v2;

	public static Gee.ArrayList<LinuxKernel> kernel_list = new Gee.ArrayList<LinuxKernel>();
	public static Gee.ArrayList<LinuxKernel> kall = new Gee.ArrayList<LinuxKernel>();

	public static Regex rex_pageuri = null;
	public static Regex rex_pageuri_arch = null;
	public static Regex rex_datetime = null;
	public static Regex rex_fileuri = null;
	public static Regex rex_header = null;
	public static Regex rex_header_all = null;
	public static Regex rex_image = null;
	public static Regex rex_image_extra = null;
	public static Regex rex_modules = null;

	// constructor
	public LinuxKernel(string v="",string f="generic") {
		vprint("LinuxKernel("+v+","+f+")",4);

		version = v;
		flavor = f;

		split_version_string();
		version_main = version;
		if (flavor!="generic") version_main+="_"+flavor;

		// for cache dir, strip off "_flavor"
		CACHE_KDIR = Main.CACHE_DIR+"/"+version;
		CACHED_PAGE = CACHE_KDIR+"/index.html";
		CHECKSUMS_FILE = CACHE_KDIR+"/CHECKSUMS";
		INVALID_FILE = CACHE_KDIR+"/invalid";

		// for data dir, do not strip off "_flavor"
		DATA_KDIR = Main.DATA_DIR+"/"+version_main;
		NOTES_FILE = DATA_KDIR+"/notes";
		LOCKED_FILE = DATA_KDIR+"/locked";
	}

	// wrap kernel_list.add(k) to avoid doing some work unless we're actually going to use it
	public void kernel_list_add() {
		vprint("kernel_list_add("+this.version_main+")",4);

		foreach (var k in kernel_list) {
			if (k.version_main == this.version_main) {
				vprint("Merging kernel info for " + this.version_main, 4);
				if (this.is_installed) k.is_installed = true;
				if (this.is_running) k.is_running = true;
				if (this.is_locked) k.is_locked = true;
				if (this.is_invalid) k.is_invalid = true;
				
				// Merge package lists
				if (this.pkg_list.length > 0) {
					foreach (var p in this.pkg_list) {
						bool found = false;
						foreach (var ep in k.pkg_list) {
							if (ep == p) { found = true; break; }
						}
						if (!found) {
							string[] l = k.pkg_list;
							l += p;
							k.pkg_list = l;
						}
					}
				}
				
				// Merge package URL lists
				foreach (var entry in this.pkg_url_list.entries) {
					k.pkg_url_list[entry.key] = entry.value;
				}

				k.set_status();
				return;
			}
		}

		REPO_DIRS_VER = repo_dirs_ver();
		CHECKSUMS_URI = checksums_uri();
		if (exists(NOTES_FILE)) notes = fread(NOTES_FILE).strip();
		is_invalid = exists(INVALID_FILE);
		is_locked = exists(LOCKED_FILE);
		set_status();

		kernel_list.add(this);
	}

	// class initialize
	public static void initialize() {
		vprint("LinuxKernel initialize()",3);
		new LinuxKernel(); // instance must be created before setting static members

		MAIN_INDEX_FILE = Main.CACHE_DIR+"/index.html";

		vprint("LinuxKernel: check_distribution...", 3);
		LINUX_DISTRO = check_distribution();
		
		vprint("LinuxKernel: check_package_architecture...", 3);
		NATIVE_ARCH = check_package_architecture();
		
		vprint("LinuxKernel: check_running_kernel...", 3);
		RUNNING_KERNEL = check_running_kernel();
		
		vprint("LinuxKernel: initialize_regex...", 3);
		initialize_regex();

		kernel_active = new LinuxKernel(RUNNING_KERNEL);
		kernel_latest_installed = kernel_active;
		kernel_oldest_installed = kernel_active;
		kernel_latest_available = kernel_active;
		kernel_update_major = kernel_active;
		kernel_update_minor = kernel_active;

		// Special threshold kernel versions where the mainline-repo site changed their directory structure.
		// repo_dirs_ver=1       repo_dirs_ver=2
		// ./foo.pkg.tar.zst       vs   ./<arch>/foo.pkg.tar.zst
		// ./CHECKSUMS     vs   ./<arch>/CHECKSUMS
		// ./BUILT         vs   ./<arch>/status
		kernel_last_stable_repo_dirs_v1 = new LinuxKernel("5.6.17");
		kernel_last_unstable_repo_dirs_v1 = new LinuxKernel("5.7-rc7");
		//kernel_last_stable_repo_dirs_v2 = new LinuxKernel("x.y.z"); // if the site changes again
		//kernel_last_unstable_repo_dirs_v2 = new LinuxKernel("x.y-rcZ");
	}

	// dep: lsb_release, os-release
	public static string check_distribution() {
		vprint("check_distribution()",3);
		string dist = "";

		string std_out, std_err;
		int e = exec_sync_argv({"lsb_release", "-sd"}, out std_out, out std_err);
		if ((e == 0) && (std_out != null)) {
			dist = std_out.strip();
		} else if (exists("/etc/os-release")) {
			// Fallback to /etc/os-release for Arch Linux
			string content = fread("/etc/os-release");
			foreach (var line in content.split("\n")) {
				if (line.has_prefix("PRETTY_NAME=")) {
					dist = line.replace("PRETTY_NAME=", "").replace("\"", "").strip();
					break;
				}
			}
		}

		if (dist != "") {
			vprint(_("Distribution")+": "+dist,2);
		}

		return dist;
	}

	// dep: uname
	public static string check_package_architecture() {
		vprint("check_package_architecture()",3);
		string arch = "";

		string std_out, std_err;
		int e = exec_sync_argv({"uname", "-m"}, out std_out, out std_err);
		if ((e == 0) && (std_out != null)) {
			arch = std_out.strip();
			vprint(_("Architecture")+": "+arch,2);
		}

		return arch;
	}

	// dep: uname
	public static string check_running_kernel() {
		vprint("check_running_kernel()",3);
		string ver = "";

		string std_out;
		exec_sync_argv({"uname", "-r"}, out std_out, null);
		ver = std_out.strip().replace("\n","");

		return ver;
	}


	public static void initialize_regex() {
		vprint("initialize_regex()",3);
		try {

			// uri to a kernel page and it's datetime, in the main index.html
			// Arch:   <a href="linux-4.20.10.arch1-1-x86_64.pkg.tar.xz">linux-4.20.10.arch1-1-x86_64.pkg.tar.xz</a> 15-Feb-2019 19:17 70M
			rex_pageuri     = new Regex("""href="((?:v|linux-)(.+?)(?:/|-x86_64\.pkg\.tar\.(?:xz|zst)))".+?([0-9]{2,4}-([0-9]{2}|[A-Z][a-z]{2})-[0-9]{2,4})[\t ]+([0-9]{2}:[0-9]{2})""");
			rex_pageuri_arch = new Regex("""href="(linux-([0-9a-zA-Z._-]+?)-x86_64\.pkg\.tar\.(?:xz|zst))".+?([0-9]{2,4}-([0-9]{2}|[A-Z][a-z]{2})-[0-9]{2,4})[\t ]+([0-9]{2}:[0-9]{2})""");

			// date & time for any uri in a per-kernel page
			rex_datetime    = new Regex(""">[\t ]*([0-9]{2,4}-([0-9]{2}|[A-Z][a-z]{2})-[0-9]{2,4})[\t ]+([0-9]{2}:[0-9]{2})""");

			// uri to any package file in a per-kernel page
			rex_fileuri     = new Regex("href=\"(.+\\.pkg\\.tar\\.(?:xz|zst))\"");

			rex_image       = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-.+-(.+)_(.+)_(?:all|""" + NATIVE_ARCH + """)\.pkg\.tar\.(?:xz|zst)""");
			rex_image_extra = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-extra-.+-(.+)_(.+)_(?:all|""" + NATIVE_ARCH + """)\.pkg\.tar\.(?:xz|zst)""");
			rex_modules     = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-modules-.+-(.+)_(.+)_(?:all|""" + NATIVE_ARCH + """)\.pkg\.tar\.(?:xz|zst)""");
			rex_header      = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-.+-(.+)_(.+)_(?:all|""" + NATIVE_ARCH + """)\.pkg\.tar\.(?:xz|zst)""");
			rex_header_all  = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-.+_all\.pkg\.tar\.(?:xz|zst)""");

		} catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	static void trim_cache() {
		if (App.keep_cache) return;
		foreach (var k in kall) {
			if (k.is_installed) continue;
			// don't remove anything >= threshold_major even if hidden
			if (k.version_major<THRESHOLD_MAJOR && File.parse_name(k.CACHE_KDIR).query_exists()) rm(k.CACHE_KDIR);
		}
	}

	public static void delete_cache() {
		vprint("delete_cache()",3);
		App.index_is_fresh = false;
		kernel_list.clear();
		kall.clear();
		rm(Main.CACHE_DIR);
	}

	public void set_invalid(bool b) {
		if (b) fwrite(INVALID_FILE,"");
		else rm(INVALID_FILE);
		is_invalid = b;
	}

	public void set_locked(bool b) {
		if (b) fwrite(LOCKED_FILE,"");
		else rm(LOCKED_FILE);
		is_locked = b;
	}

	public void set_notes(string s="") {
		if (s.length>0) fwrite(NOTES_FILE,s);
		else rm(NOTES_FILE);
		notes = s;
	}

	public void set_status() {
		status =
			is_running ? _("Running") :
			is_installed ? _("Installed") :
			is_invalid ? _("Invalid") :
			_("Available");
	}

	public delegate void Notifier(bool last = false);

	public static void mk_kernel_list(bool wait = true, owned Notifier? notifier = null) {
		vprint("mk_kernel_list()",3);
		try {
			var worker = new Thread<bool>.try(null, () => mk_kernel_list_worker((owned)notifier) );
			if (wait) worker.join();
		} catch (Error e) { vprint(e.message,1,stderr); }
	}

	static bool mk_kernel_list_worker(owned Notifier? notifier) {
		vprint("mk_kernel_list_worker()",3);
		if ((!App.gui_mode && !App.index_is_fresh) || Main.VERBOSE>1) vprint("Updating Kernels...");

		kernel_list.clear();
		App.progress_total = 0;
		App.progress_count = 0;
		App.cancelled = false;

		// find the oldest major version to include
		Package.mk_pacman_list();
		find_thresholds();

		// ===== download the main index.html listing all kernels =====
		download_main_index(); // download the main index.html
		load_main_index();  // scrape the main index.html to make the initial kernel_list

		// ===== download the per-kernel index.html and CHANGES =====

		// list of kernels - one LinuxKernel object per kernel to update
		var kernels_to_update = new Gee.ArrayList<LinuxKernel>();
		// list of files - one DownloadItem object per individual file to download
		var downloads = new Gee.ArrayList<DownloadItem>();

		// add files to download list
		vprint(_("loading cached pages"),3);
		foreach (var k in kernel_list) {
			if (App.cancelled) break;

			// skip some kernels for various reasons

			// don't try to skip this kernel by looking at is_invalid yet.
			// is_invalid is cached and might be obsolete

			// try to load cached info for this kernel
			if (k.load_cached_page()) continue;

			// now we can consider is_invalid
			// an invalid kernel might be installed, but that would have to
			// be a distro kernel or self-compiled, not a mainline-repo one,
			// so it's ok to filter out an invalid mainline-repo one here
			if (k.is_invalid && App.hide_invalid) continue;

			// there may be installed rc kernels even if rc are currently disabled
			// so don't try to filter out rc kernels yet

			// we have either not found a cached page,
			// or found it to be out of date and deleted it,
			// and have not skipped this kernel due to is_invalid

			// add index.html to download list
			vprint(_("queuing download")+" "+k.version_main,3);
			downloads.add(new DownloadItem(k.page_uri,Path.get_dirname(k.CACHED_PAGE),Path.get_basename(k.CACHED_PAGE)));

			// add kernel to update list
			kernels_to_update.add(k);

			if (notifier != null) notifier();
		}

		// process the download list
		if (downloads.size>0 && App.repo_up) {

			// download the indexes
			vprint(_("downloading new pages"),3);
			App.progress_total = downloads.size;
			var mgr = new DownloadTask();
			foreach (var item in downloads) mgr.add_to_queue(item);
			mgr.execute();
			while (mgr.is_running) {
				App.progress_count = mgr.prg_count;
				pbar(App.progress_count,App.progress_total);
				Thread.usleep(250000);
				if (notifier != null) notifier();
			}
			pbar(0,0);

			// load the indexes
			vprint(_("loading new pages"),3);
			foreach (var k in kernels_to_update) {
				k.load_cached_page();
				k.set_status();
			}
			if (notifier != null) notifier();

		}

		check_installed();
		trim_cache();
		check_updates();

		// print summary
		if (Main.VERBOSE>1) {
			vprint(_("Currently Running")+": "+kernel_active.version_main);
			vprint(_("Oldest Installed")+": "+kernel_oldest_installed.version_main);
			vprint(_("Newest Installed")+": "+kernel_latest_installed.version_main);
			vprint(_("Newest Available")+": "+kernel_latest_available.version_main);
			if (kernel_update_minor!=null) vprint(_("Available Minor Update")+": "+kernel_update_minor.version_main);
			if (kernel_update_major!=null) vprint(_("Available Major Update")+": "+kernel_update_major.version_main);
		}

		// This is here because it had to be delayed from whenever settings
		// changed until now, so that the notify script instance of ourself
		// doesn't do it's own mk_kernel_list() at the same time while we still are.
		App.run_notify_script_if_due();

		if (notifier != null) notifier(true);
		return true;
	}

	// download the main index.html listing all mainline kernels
	static bool download_main_index() {
		vprint("download_main_index()",3);

		if (!exists(MAIN_INDEX_FILE)) App.index_is_fresh=false;
		if (App.index_is_fresh) return true;
		if (!App.try_repo()) return false;

		mkdir(Main.CACHE_DIR);

		// preserve the old index in case the dl fails
		string tbn = "%8.8X".printf(Main.rnd.next_int());
		string tfn = Main.CACHE_DIR+"/"+tbn;
		vprint("+ DownloadItem("+App.repo_uri+","+Main.CACHE_DIR+","+tbn+")",4);
		var item = new DownloadItem(App.repo_uri, Main.CACHE_DIR, tbn);
		var mgr = new DownloadTask();
		mgr.add_to_queue(item);

		mgr.execute();
		while (mgr.is_running) Thread.usleep(250000);

		if (exists(tfn)) {
			FileUtils.rename(tfn,MAIN_INDEX_FILE);
			App.index_is_fresh=true;
			vprint(_("OK"),3);
			return true;
		} else {
			vprint(_("FAILED"),1,stderr);
			return false;
		}
	}

	// read the main index.html listing all kernels
	static void load_main_index() {
		vprint("load_main_index()",3);
		if (THRESHOLD_MAJOR<0) { vprint("load_index(): MISSING THRESHOLD_MAJOR", 1, stderr); return; }

		if (!exists(MAIN_INDEX_FILE)) return;
		string txt = fread(MAIN_INDEX_FILE);
		kernel_list.clear();
		kall.clear();

		MatchInfo mi;
		bool is_arch = App.repo_uri.contains("archlinux.org");

		Gee.HashMap<string, LinuxKernel> arch_latest_builds = new Gee.HashMap<string, LinuxKernel>();

		foreach (string l in txt.split("\n")) {
			Regex current_rex = is_arch ? rex_pageuri_arch : rex_pageuri;
			if (!current_rex.match(l, 0, out mi)) continue;
			var u = mi.fetch(1);
			if (u != null && !u.validate()) continue;
			var v = mi.fetch(2);
			if (v != null && !v.validate()) v = "";
			var k = new LinuxKernel(v);
			k.page_uri = App.repo_uri + u;
			k.is_mainline = true;

			var d = mi.fetch(3);
			if (d != null && !d.validate()) d = "";
			k.release_date = d;

			if (is_arch) {
				k.pkg_url_list[u] = k.page_uri;
				k.name = "linux";
				k.vers = v;
				k.flavor = "generic";
				
				// Deduplicate builds: keep only the latest pkgrel for each base version
				string base_ver = v;
				int dash_idx = v.last_index_of("-");
				if (dash_idx > 0) base_ver = v.substring(0, dash_idx);
				
				if (arch_latest_builds.has_key(base_ver)) {
					var existing = arch_latest_builds[base_ver];
					if (k.compare_to(existing) > 0) {
						arch_latest_builds[base_ver] = k;
					}
				} else {
					arch_latest_builds[base_ver] = k;
				}
				continue;
			}
			
			if (k.version_major>=THRESHOLD_MAJOR) {
				k.repo_datetime = 0;
				k.kernel_list_add(); // the active list
			}
			kall.add(k); // a seperate list with nothing removed, used in trim_cache()
		}

		if (is_arch) {
			foreach (var k in arch_latest_builds.values) {
				if (k.version_major>=THRESHOLD_MAJOR) {
					k.repo_datetime = 0;
					k.kernel_list_add();
				}
				kall.add(k);
			}
		}

		if (kall.size > 0 && kernel_list.size == 0) {
			vprint(_("All available kernels were filtered out by 'Hide previous major versions' setting (Major version threshold: %d)").printf(THRESHOLD_MAJOR), 1, stderr);
		}

		// sort the list, highest first
		kernel_list.sort((a,b) => { return b.compare_to(a); });

	}

	public static void check_installed() {
		vprint("check_installed()",3);

		//string msg = "";

		if (Package.pacman_list.size<1) vprint("!!! pacman_list empty!");
		if (kernel_list.size<1) vprint("!!! kernel_list empty!");

		foreach (var p in Package.pacman_list) {
			if (!p.name.has_prefix("linux-image-") && !p.name.has_prefix("linux-") && p.name != "linux") continue;
			
			// Exclude common non-kernel packages
			if (p.name.has_suffix("-headers") || p.name.contains("-firmware") || p.name.has_suffix("-api-headers") || p.name.contains("-meta") || p.name.contains("-docs")) continue;
			
			vprint("\t"+p.name,3);

			// search kernel_list for matching package and version
			bool found_mainline = false;
			foreach (var k in kernel_list) {
				if (k.name != p.name) continue;
				
				// On Arch, package name is just 'linux', so we MUST check version too
				if (k.name == "linux" || k.name.has_prefix("linux-")) {
					var tv = k.vers;
					var pv = p.vers;
					var tvs = tv.split(".");
					var pvs = pv.split(".");
					if (tvs.length > 0 && pvs.length > 0) {
						var tvse = tvs[tvs.length-1];
						var pvse = pvs[pvs.length-1];
						if (tvse.length==12 && uint64.parse(tvse)>0) tv = tv.substring(0,tv.length-13);
						if (pvse.length==12 && uint64.parse(pvse)>0) pv = pv.substring(0,pv.length-13);
					}
					if (tv != pv) continue;
				}
				
				found_mainline = true;
				k.is_installed = true;
				k.set_status();
				k.set_pkg_list();
				break;
			}

			// installed package was not found in the mainline list
			// add to kernel_list as a distro kernel
			if (!found_mainline) {
				// FIXME - See also load_cached_page() rex_image
				//
				// We have to somehow determine the "flavor" from the information
				// available from pacman. The flavor is part of p.name, but it's
				// hard to isolate it, because although it is always a suffix
				// seperated by "-", like "-foo", "foo" itself can also contain
				// anything, including "-". "###-generic-64k"  "###-generic-lpae"
				//
				// And the stuff before flavor isn't consistent either. The trailing
				// end of the version component might contain anything, including
				// non-numbers and multiple "." and "-", so there is no regex
				// to tell where the version ends and the flavor begins.
				//
				// You can't count the number of "-" because that is also variable.
				// Both the beginning name component and the version component may contain
				// variable numbers of "-". "linux-image-#..." "linux-image-unsigned-#..."
				//
				// So we are merely splitting on "-" and calling the last field the "flavor".
				//
				// Right now at least the mechanics are working because check_installed()
				// and load_cached_page() are both arriving at the same value for "flavor"
				// for a given kernel, which is then needed by set_pkg_list().
				// As long as it's only used internally as a unique identifier,
				// then it only needs to be unique and reproducible from the different
				// sources of info like pacman and web pages, not meaningfully correct.
				//
				// The problems are:
				// * It will break if there is ever a flavor named "64k" or
				//   "someother-64k", at the same time with "generic-64k",
				//   in the same arch, in the same base kernel version.
				// * We are displaying this wrong "flavor" value in the kernel
				//   list in the form of the constructed value version_main.
				//
				// Mostly no one sees the problem because the x86_64 arch doesn't
				// happen to have any flavors with embedded "-" so far.
				//
				var x = p.name.split("-");
				string flv = x[x.length-1];
				if (App.repo_uri.contains("archlinux.org") && flv == "linux") flv = "generic";
				var k = new LinuxKernel(p.vers,flv);
				k.name = p.name;
				k.vers = p.vers;
				k.is_mainline = false;
				k.is_installed = true;
				//vprint("non-mainline: n:"+k.name+" v:"+k.vers+" f:"+k.flavor);
				k.set_pkg_list();
				k.kernel_list_add();
			}
		}

		// find kernels manually installed in /boot
		check_boot_directory();

		// kernel_list contains both mainline and installed distro kernels now
		// find the running kernel
		var s = "-"+RUNNING_KERNEL;
		foreach (var k in kernel_list) {
			if (k.version.replace("-",".") == RUNNING_KERNEL.replace("-",".") || k.name.has_suffix(s)) {
				k.is_running = true;
				k.is_installed = true;
				vprint("Auto-locking running kernel: " + k.version_main, 2);
				k.set_locked(true);
				k.set_status();
				kernel_active = k;
				break;
			}
		}

		// sort, reverse
		kernel_list.sort((a,b) => { return b.compare_to(a); });

		// find the highest & lowest installed versions
		kernel_latest_installed = new LinuxKernel();
		kernel_oldest_installed = kernel_latest_installed;
		foreach(var k in kernel_list) {
			if (k.is_installed) {
				k.set_status();
				if (kernel_latest_installed.version_major==0) kernel_latest_installed = k;
				kernel_oldest_installed = k;
				//msg = _("Found installed")+": "+k.name;
				//if (k.is_locked) msg += " (" + _("locked") +")";
				//if (k.is_running) msg += " (" + _("running") +")";
				//vprint(msg,2);
			}
		}
	}

	public static void check_boot_directory() {
		vprint("check_boot_directory()", 3);
		try {
			var dir = File.new_for_path("/boot");
			if (!dir.query_exists()) return;

			var enumerator = dir.enumerate_children("standard::name", FileQueryInfoFlags.NONE);
			FileInfo info;
			while ((info = enumerator.next_file()) != null) {
				string name = info.get_name();
				if (!name.has_prefix("vmlinuz-")) continue;
				
				string kversion = name.substring(8); // strip "vmlinuz-"
				if (kversion.has_prefix("linux-")) kversion = kversion.substring(6); // strip "linux-"
				if (kversion == "linux") continue; // handled by pacman or too generic

				// Compute the base numeric version (e.g. "6.19.14" from "6.19.14.arch1-1")
				// by walking the dot-separated parts and stopping at the first non-numeric one.
				// Avoids Gee.ArrayList.to_array() which would generate a void** cast warning.
				string kversion_base = kversion;
				{
					var parts = kversion.split(".");
					var sb = new StringBuilder();
					foreach (var p in parts) {
						bool all_digits = p.length > 0;
						for (int ci = 0; ci < p.length; ci++) {
							if (p[ci] < '0' || p[ci] > '9') { all_digits = false; break; }
						}
						if (!all_digits) break;
						if (sb.len > 0) sb.append_c('.');
						sb.append(p);
					}
					if (sb.len > 0) kversion_base = sb.str;
				}
				
				// check if already in list
				bool found = false;
				foreach (var k in kernel_list) {
					// Match by full version string, or by base numeric version (e.g. "6.19.14"),
					// or by vers (the arch package version like "6.19.14.arch1-1")
					if (k.vers == kversion
						|| k.version == kversion
						|| k.version == kversion_base
						|| k.version_main == kversion) {
						found = true;
						k.is_installed = true;
						k.set_status();
						vprint("check_boot_directory: matched " + name + " -> " + k.version_main, 3);
						break;
					}
				}
				
				if (!found) {
					vprint("Found extra kernel in /boot: " + name + " (ver=" + kversion + " base=" + kversion_base + ")", 2);
					// Use the base numeric version for the kernel object so version comparisons work
					var k = new LinuxKernel(kversion_base.length > 0 ? kversion_base : kversion);
					k.name = "linux-" + kversion; // human-readable name derived from file
					k.vers = kversion;             // full version string (e.g. "6.19.14.arch1-1")
					k.flavor = App.repo_uri.contains("archlinux.org") ? "generic" : "distro";
					k.is_mainline = App.repo_uri.contains("archlinux.org");
					k.is_installed = true;
					k.status = _("Installed (Boot)");
					k.kernel_list_add();
				}
			}
		} catch (Error e) {
			vprint("Error scanning /boot: " + e.message, 2);
		}
	}

	// scan kernel_list for versions newer than latest installed
	public static void check_updates() {
		vprint("check_updates()",3);
		kernel_update_major = null;
		kernel_update_minor = null;
		kernel_latest_available = kernel_latest_installed;

		bool major_available = false;
		bool minor_available = false;

		foreach(var k in kernel_list) {
			vprint(k.version_main,3);
			if (k.is_invalid) continue;
			if (k.is_installed) continue;
			if (k.is_locked) continue;
			if (k.is_unstable && App.hide_unstable) continue;
			if (k.version_major < THRESHOLD_MAJOR) break;
			if (k.compare_to(kernel_latest_installed)<1) break;

			// kernel_list is sorted so first match is highest match
			if (k.version_major > kernel_latest_installed.version_major) major_available = true;
			else if (k.version_major == kernel_latest_installed.version_major) {
				if (k.version_minor > kernel_latest_installed.version_minor) major_available = true;
				else if (k.version_minor == kernel_latest_installed.version_minor) {
					if (k.version_micro > kernel_latest_installed.version_micro) minor_available = true;
					else if (k.version_micro == kernel_latest_installed.version_micro) {
						if (k.version_rc > kernel_latest_installed.version_rc) minor_available = true;
					}
				}
			}

			if (major_available && (kernel_update_major == null)) kernel_update_major = k;
			if (minor_available && (kernel_update_minor == null)) kernel_update_minor = k;

			// if we have everything possible, skip the rest
			if (kernel_update_major != null && kernel_update_minor != null) break;
		}

		if (kernel_update_minor != null) kernel_latest_available = kernel_update_minor;
		if (kernel_update_major != null) kernel_latest_available = kernel_update_major;
	}

	// There is a circular dependency here.
	// (1) Ideally we want to know THRESHOLD_MAJOR before running mk_kernel_list(),
	//     so mk_kernel_list() can use it to set bounds on the size of it's job,
	//     instead of processing all kernels since the beginning of time, every time.
	// (2) Ideally we want to use is_mainline while finding THRESHOLD_MAJOR,
	//     to prevent non-mainline kernels from pulling THRESHOLD_MAJOR down.
	// (3) The only way to find out is_mainline for real is to scan kernel_list[],
	//     and see if a given installed package matches one of those.
	// (4) But we don't have kernel_list[] yet, and we can't get it yet, because GOTO (1)
	// 
	// So for this early task, we rely on a weak assumption made previously in
	// split_version_string(), when mk_pacman_list() generates some kernel objects from
	// the installed package info from pacman, which is just that if the version
	// has 12 bytes after a ".", then it's an installed mainline package.
	//
	// TODO maybe...
	// Get a full kernel_list from a preliminary pass with load_index() before runing mk_pacman_list().
	// Have mk_pacman_list() use that to fill in a real actual is_mainline for each item in pacman_list[].
	// Use that here, and along the way delete the unwanted items from kernel_list[].
	// Then mk_kernel_list() can just process that kernel_list[].
	//
	static void find_thresholds() {
		vprint("find_thresholds()",3);

		if (Package.pacman_list.size<1) { vprint("MISSING pacman_list", 1, stderr); return; }

		if (App.previous_majors<0 || App.previous_majors>=kernel_latest_available.version_major) { THRESHOLD_MAJOR = 0; return; }

		// start from the latest available and work down, ignore distro kernels
		kernel_oldest_installed = kernel_latest_installed;
		foreach (var p in Package.pacman_list) {
			if (!p.name.has_prefix("linux-image-") && !p.name.has_prefix("linux-") && p.name != "linux") continue;
			if (p.name.has_suffix("-headers") || p.name.contains("-firmware") || p.name.contains("-meta")) continue;

			var k = new LinuxKernel(p.vers);
			if (k.version_major < kernel_oldest_installed.version_major && k.is_mainline) kernel_oldest_installed = k;
		}

		THRESHOLD_MAJOR = kernel_latest_available.version_major - App.previous_majors;
		if (kernel_oldest_installed.is_mainline && kernel_oldest_installed.version_major < THRESHOLD_MAJOR) THRESHOLD_MAJOR = kernel_oldest_installed.version_major;
	}

	// two main forms of input string:
	//
	// directory name & display version from the mainline-repo web site
	// with or without leading "v" and/or trailing "/"
	//    v4.4-rc2+cod1/
	//    v4.2-rc1-unstable/
	//    v4.4.10-xenial/
	//    v4.6-rc2-wily/
	//    v4.2.8-ckt7-wily/
	//    v2.6.27.62/
	//    v4.19.285/
	//    v5.12-rc1-dontuse/
	//    v6.0/         trailing .0 but only one (not "6", nor "6.0.0")
	//    v6.0-rc5/
	//    v6.1/         no trailing .0 (not 6.1.0)
	//    v6.1-rc8/
	//    v6.1.9/
	//
	// version field from pacman from installed packages
	//    5.19.0-42.43                  distro package
	//    5.4.0-155.172                 distro package
	//    6.3.6-060306.202306050836     mainline package
	//    4.6.0-040600rc1.201603261930  sigh, rc without a delimiter, and "040600" is not always 6 characters
	//
	// We don't actually know is_mainline for sure yet, so at this point we just
	// assume if it has 12 bytes after a ".", it's an installed mainline package.
	//
	// TODO: this should be split into seperate parsers for each type of version string,
	// or maybe seperate modes controlled by a parameter.
	// Ukuu originally did have a 2nd constructor .from_version(), but it didn't actually
	// do anything useful, they still both used the same split_version_string().

	void split_version_string() {
		//vprint("\n-new-: "+s);
		version_major = 0;
		version_minor = 0;
		version_micro = 0;
		version_rc = 0;
		version_extra = "";
		is_mainline = true;
		is_unstable = false;

		string t = version.strip();
		if (t.has_prefix("v")) t = t.substring(1);
		if (t.has_suffix("/")) t = t.substring(0, t.length - 1);

		if (t==null || t=="") t = "0";
		version = t;

		//vprint("\n"+t);

		var chunks = version.split_set(".-_+~ ");
		int i = 0, n = 0;
		bool in_triplet = true;
		foreach (string chunk in chunks) {
			if (chunk.length<1) continue;
			if (chunk.has_prefix("rc")) { version_rc = int.parse(chunk.substring(2)); in_triplet = false; continue; }
			
			// Check if the chunk is purely numeric
			bool is_numeric = true;
			for (int j = 0; j < chunk.length; j++) if (!(chunk[j] >= '0' && chunk[j] <= '9')) { is_numeric = false; break; }

			if (is_numeric && in_triplet) {
				n = int.parse(chunk);
				++i;
				switch (i) {
					case 1: version_major = n; continue;
					case 2: version_minor = n; continue;
					case 3: version_micro = n; in_triplet = false; continue;
					default: in_triplet = false; break;
				}
			} else {
				in_triplet = false;
			}

			if (i >= 3) { // Already have major.minor.micro
				if (chunk.length==12) continue;
				if (chunk.has_prefix("arch")) continue;
				// If it's not numeric and we already have the version, it might be extra info
				if (!is_numeric) is_mainline = false;
			}
			version_extra += "."+chunk;
		}
		version_sort = "%d.%d.%d".printf(version_major,version_minor,version_micro);
		if (version_rc>0) version_sort += ".rc"+version_rc.to_string();
		version_sort += version_extra;

		if (version_rc>0 || version_extra.contains("unstable")) is_unstable = true;
		//vprint("major: %d\nminor: %d\nmicro: %d\nrc   : %d\nextra: %s\nunstable: %s\nsort :%s".printf(version_major,version_minor,version_micro,version_rc,version_extra,is_unstable.to_string(),version_sort));
		//vprint(version_sort);
	}

// complicated comparison logic for kernel versions
// * version_sort is delimited by . so the individual chunks can be numerically compared
//   so 1.2.3-rc4-unstable is 1.2.3.rc4.unstable
// * version_sort has at least the first 3 chunks filled with at least 0
//   so 6 is 6.0.0
// * 1.12.0 is higher than 1.2.0
// * 1.2.3-rc5 is higher than 1.2.3-rc4
// * 1.2.3 is higher than 1.2.3-rc4
// * 1.2.3 is higher than 1.2.3-unstable
// * 1.2.3-rc4 is higher than 1.2.3-rc4-unstable
//
// TODO version_sort is a transitional hack to keep doing the old way of
// parsing version_main, since version_main has a different format now.
// The better way will be to just examine the individual variables
// which we already did the work of parsing in split_version_string()
//
// like strcmp(l,r), but l & r are LinuxKernel objects
// l.compare_to(r)   name & interface to please Gee.Comparable
//  l<r  return -1
//  l==r return 0
//  l>r  return 1
	public int compare_to(LinuxKernel t) {
		if (Main.VERBOSE>4) vprint(version_main+" compare_to() "+t.version_main);
		var a = version_sort.split(".");
		var b = t.version_sort.split(".");
		int x, y, i = -1;
		while (++i<a.length && i<b.length) {            // while both strings have chunks
			if (a[i] == b[i]) continue;                 // both the same, next chunk
			x = int.parse(a[i]); y = int.parse(b[i]);   // parse strings to ints
			if (x>0 && y>0) return (x - y);             // both numeric>0, numeric compare
			if (x==0 && y==0) return strcmp(a[i],b[i]); // neither numeric>0 (alpha or maybe 0), lex compare
			if (x>0) return 1;                          // only left is numeric>0, left is greater
			return -1;                                  // only right is numeric>0, right is greater
		}
		if (i<a.length) { if (int.parse(a[i])>0) return 1; return -1; } // if left is longer { if left is numeric>0, left is greater else right is greater }
		if (i<b.length) { if (int.parse(b[i])>0) return -1; return 1; } // if right is longer { if right is numeric>0, right is greater else left is greater }
		return 0;                                       // left & right identical the whole way
	}

	void set_pkg_list() {
		vprint("set_pkg_list("+version_main+")",3);
		foreach(var p in Package.pacman_list) {
			//vprint("vers="+vers+"\tp.vers="+p.vers,4);
			// BLARGH!!!!
			// The mainline-repo site sometimes updates and replaces packages after
			// you've installed them. The new packages have the same base name & version,
			// just with a new later .123456789012 datestamp suffix in the vers field.
			// This breaks us because the 'vers' we get from todays index.html
			// no longer matches the 'p.vers' we get from the installed packages in pacman.
			//
			// pkg on archive.archlinux.org today   installed pkg from archive.archlinux.org a week ago
			// vers=6.4.6-060406.202308041557   p.vers=6.4.6-060406.202307241739
			//
			// Until I think of a better way, strip off the .datetime before compare.
			//
			// It's crap. Two builds with only different datetime should be
			// installable and removable side-by-side, but we just have very little
			// reliable way to associate package info with mainline-repo site info.
			// This code to do the crappy thing is itself also brute force crap, but working,
			// if you can call deliberately ignoring a part of a unique key value "working".
			var tv = vers;
			var pv = p.vers;
			var tvs = tv.split(".");
			var pvs = pv.split(".");
			var tvse = tvs[tvs.length-1];
			var pvse = pvs[pvs.length-1];
			//vprint("tvse="+tvse+"\tpvse="+pvse);
			// if the last part is exactly 12 bytes long, and is all numbers, then strip it off.
			if (tvse.length==12 && uint64.parse(tvse)>0) tv = tv.substring(0,tv.length-13);
			if (pvse.length==12 && uint64.parse(pvse)>0) pv = pv.substring(0,pv.length-13);
			// TODO - if tvse>pvse alert user that the package has been updated on the server.
			// TODO - preserve a copy of cached_page at install-time until the matching
			// packages are uninstalled, so we can track builds seperately like versions,flavors,archs
			//vprint("tv="+tv+"\tpv="+pv);
			if (pv != tv) continue;
			
			// On Arch, the main package is just 'linux', but can also be 'linux-headers' etc.
			bool is_arch = App.repo_uri.contains("archlinux.org");
			bool is_arch_main = is_arch && (p.name == "linux" || p.name.has_prefix("linux-"));
			
			if (!is_arch_main && !p.name.has_suffix("-"+flavor) && p.arch != "all") continue;
			var l = pkg_list;
			l += p.name;
			pkg_list = l;
			vprint("  p: "+p.name,3);
		}
	}

	int repo_dirs_ver() {
		int v = 1;
		var k = kernel_last_stable_repo_dirs_v1;                // Which threshold,
		if (is_unstable) k = kernel_last_unstable_repo_dirs_v1; // stable or unstable?
		if (compare_to(k)>0) v = 2;                 // Do we exceed it?
		// in the future if the repo site changes again,
		// add more copies of these 3 lines
		//if (this.compare_to(kernel_last_stable_repo_dirs_v1) < 1) return 1;
		//if (this.compare_to(kernel_last_unstable_repo_dirs_v1) < 1) return 1;
		//if (compare_to(k)>0) v = 3;
		return v;
	}

	string checksums_uri() {
		if (REPO_DIRS_VER == 1) return App.repo_uri + version + "/CHECKSUMS";
		//case 2: return page_uri+NATIVE_ARCH+"/CHECKSUMS";
		return page_uri+NATIVE_ARCH+"/CHECKSUMS";
	}

	public string tooltip_text() {
		string txt = "";

		// available packages
		string list = "";
		foreach (var x in pkg_url_list.keys) list += "\n"+x;
		if (list.length > 0) txt += "<b>"+_("Packages Available")+"</b>"+list;

		// installed packages
		list = "";
		foreach (var x in pkg_list) list += "\n"+x;
		if (list.length > 0) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Packages Installed")+"</b>"+list;
		}

		// user notes
		if (notes.length > 0) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Notes")+"</b>\n"+notes;
		}

		// other
		if (is_locked) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Locked")+"</b>\n";
			if (is_installed) txt += _("removal"); else txt += _("installation");
			txt += " " + _("prevented");
		}

		return txt;
	}

	// return false if we don't have the cached page
	//   or if it's older than its timestamp in the main index.html
	// return true if we have a valid cached page,
	//   whether the kernel itself is a valid build or not
	bool load_cached_page() {
		vprint("load_cached_page("+CACHED_PAGE+")",4);
		if (App.repo_uri.contains("archlinux.org")) return true; // Already populated in load_main_index
		name = "";
		vers = "";
		pkg_url_list.clear();
		if (!exists(CACHED_PAGE)) { vprint(_("not found"),4); return false; }

		string txt = "";
		int64 d_this = 0;
		int64 d_max = 0;
		MatchInfo mi;
		var _url_list = new Gee.HashMap<string,string>(); // local temp pkg_url_list
		var _flavors = new Gee.HashMap<string,string>(); // flavors[flavor]=name
		string? _flavor;
		string? _name;
		string? _vers;

		// read cached page
		txt = fread(CACHED_PAGE);

		// detect and delete out-of-date cache
		//
		// find the latest timestamp anywhere in the cached page
		foreach (string l in txt.split("\n")) {
			if (rex_datetime.match(l, 0, out mi)) {
				d_this = int64.parse(mi.fetch(1)+mi.fetch(2)+mi.fetch(3)+mi.fetch(4)+mi.fetch(5));
				if (d_this>d_max) d_max = d_this;
			}
		}
		// if this kernel's timestamp from the main index is later than the latest in this
		// kernel's cached page, then delete the cache for this kernel and return false.
		if (repo_datetime>d_max) {
			vprint(version_main+": repo:"+repo_datetime.to_string()+" > cache:"+d_max.to_string()+" : "+_("needs update"),2);
			rm(CACHE_KDIR);
			return false;
		}

		// skip the rest of the work if we already know it's a failed build
		if (is_invalid) return true;

		// scan for urls to packages
		foreach (string l in txt.split("\n")) {
			if (!rex_fileuri.match(l, 0, out mi)) continue;
			string file_uri = page_uri + mi.fetch(1);
			string file_name = Path.get_basename(file_uri);
			if (_url_list.has_key(file_name)) continue;

			_name = null;
			_vers = null;
			_flavor = null;
			if (rex_image.match(file_name, 0, out mi)) {
				// linux-*.pkg.tar.zst also defines !is_invalid and flavor

				// TODO FIXME
				// some kernels have multiple builds
				// linux-6.2.7.arch1-1-x86_64.pkg.tar.zst
				// We are not handling that at all. We end up creating a single LinuxKernel
				// for "5.16" with a pkg_url_list that has two full sets of files

				//  linux-6.2.7.arch1-1-x86_64.pkg.tar.zst
				// |                                 |--flavor---|                         |
				// |---------------------name--------------------|----------vers-----------|
				var x = file_name.split("_");
				_name = x[0];
				_vers = x[1];
				_flavor = mi.fetch(1);
				if (_flavor==null) _flavor = "generic"; // ensure !null but never actually happens
				if (_flavor=="generic") {
					name = _name;
					vers = _vers;
				}
				_flavors[_flavor] = _name;

			} else if (rex_image_extra.match(file_name, 0, out mi)) {
			} else if (rex_modules.match(file_name, 0, out mi)) {
			} else if (rex_header.match(file_name, 0, out mi)) {
			} else if (rex_header_all.match(file_name, 0, out mi)) {
			} else file_name = "";

			// if we matched a file of any kind, add it to the url list
			if (file_name.length>0) _url_list[file_name] = file_uri;

		}

		if (name.length<1) set_invalid(true);

		// create a new LinuxKernel for each detected flavor
		foreach (var flv in _flavors.keys) {
			LinuxKernel k;
			if (flv!="generic") {
				k = new LinuxKernel(version_main,flv);
				k.is_mainline = is_mainline;
				k.page_uri = page_uri;
				k.name = _flavors[flv];
				k.vers = vers;
			} else {
				k = this;
			}
			k.pkg_url_list.clear();
			foreach (var f in _url_list.keys) {
				if (f.split("_")[0].has_suffix("-"+flv) || f.has_suffix("_all.pkg.tar.zst")) k.pkg_url_list[f] = _url_list[f];
			}
			if (k != this) k.kernel_list_add();
			//vprint(k.version_main+"\t"+k.name+"\t"+k.vers);
			//foreach (var f in k.pkg_url_list.keys) vprint("  "+f);
		}

		return true;
	}

	// actions

	public static void print_list() {
		vprint("----------------------------------------------------------------");
		vprint(_("Available Kernels"));
		vprint("----------------------------------------------------------------");

		foreach(var k in kernel_list) {

			// apply filters, but don't hide any installed
			if (!k.is_installed) {
				if (k.is_invalid && App.hide_invalid) continue;
				if (k.is_unstable && App.hide_unstable) continue;
				if (k.flavor!="generic" && App.hide_flavors) continue;
			}

			vprint("%-12s %2s %-10s %s".printf(k.version_main, (k.is_locked)?"🔒":"", k.status, k.notes));
		}
	}

	public static Gee.ArrayList<LinuxKernel> vlist_to_klist(string list="") {
		vprint("vlist_to_klist("+list+")",3);
		var klist = new Gee.ArrayList<LinuxKernel>();
		var vlist = list.split_set(",;:| ");
		int i=vlist.length;
		foreach (var v in vlist) if (v.strip()=="") i-- ;
		if (i<1) return klist;
		bool e = false;
		foreach (var v in vlist) {
			e = false;
			if (v.strip()=="") continue;
			foreach (var k in kernel_list) if (k.version_main==v) { e = true; klist.add(k); break; }
			if (!e) vprint(_("Kernel")+" \""+v+"\" "+_("not found"));
		}
		return klist;
	}

	// dep: aria2c
	public bool download_packages() {
		vprint("download_packages("+version_main+")",3);
		bool r = true;
		int MB = 1024 * 1024;
		string[] flist = {};

		// For arch packages: files in the Arch Linux Archive are immutable, so skip if cached.
		// For other flavors: if keep_pkgs is false, always re-download; otherwise skip if cached.
		bool is_arch = App.repo_uri.contains("archlinux.org");
		foreach (var f in pkg_url_list.keys) {
			bool cached = exists(CACHE_KDIR+"/"+f);
			if (!cached || (!is_arch && !App.keep_pkgs)) flist += f;
		}

		// CHECKSUMS
		if (flist.length>0) {
			pkg_checksum_list.clear();
			if (App.verify_checksums && !is_arch) {
				vprint(_("checksums enabled"),2);

				// download the CHECKSUMS file
				if (!exists(CHECKSUMS_FILE)) {
					var dt = new DownloadTask();
					dt.add_to_queue(new DownloadItem(CHECKSUMS_URI,Path.get_dirname(CHECKSUMS_FILE),Path.get_basename(CHECKSUMS_FILE)));
					dt.execute();
					while (dt.is_running) Thread.usleep(100000);
				}
				if (!exists(CHECKSUMS_FILE)) return false;

				// parse the CHECKSUMS file
				// extract the sha256 hashes and save in aria2c format
				// hash  linux-6.2.7.arch1-1-x86_64.pkg.tar.zst
				// pkg_checksum_list[filename]="sha-256=hash"
				// aria2c -h#checksum  ;aria2c -v |grep "^Hash Algorithms:"
				// FIXME assumption: if 1st word is 64 bytes then it is a sha256 hash
				// FIXME assumption: there will always be exactly 2 spaces between hash & filename
				foreach (string l in fread(CHECKSUMS_FILE).split("\n")) {
					var w = l.split(" ");
					if (w.length==3 && w[0].length==64) pkg_checksum_list[w[2]] = "sha-256="+w[0];
				}
			}

			var dt = new DownloadTask();
			foreach (var f in flist) dt.add_to_queue(new DownloadItem(pkg_url_list[f],CACHE_KDIR,f,pkg_checksum_list[f]));
			vprint(_("Downloading %s").printf(version_main));
			dt.execute();
			string[] stat = {"","",""};
			var t = pkg_url_list.size.to_string();
			while (dt.is_running) {
				stat = dt.status_line.split_set(" /");
				if (stat[1]!=null && stat[2]!=null) pbar(int64.parse(stat[1])/MB,int64.parse(stat[2])/MB,"MB - file "+(dt.prg_count+1).to_string()+"/"+t);
				Thread.usleep(250000);
			}
			pbar(0,0);
		}

		foreach (string f in pkg_url_list.keys) if (!exists(CACHE_KDIR+"/"+f)) r = false;
		return r;
	}

// ---------------------------------------------------------------------
// detect_bootloader()
// get_kernel_cmdline()
// update_bootloader_add()
// update_bootloader_remove()
// lock_vlist() / lock_klist()
// download_vlist() / download_klist()
// install_vlist() / install_klist()
// uninstall_vlist() / uninstall_klist()

	// Returns "grub", "systemd-boot", or "unknown"
	public static string detect_bootloader() {
		if (exists("/boot/loader/loader.conf") || exists("/efi/loader/loader.conf")) return "systemd-boot";
		if (exists("/boot/grub/grub.cfg") || exists("/boot/grub2/grub.cfg")) return "grub";
		return "unknown";
	}

	// Returns the kernel boot options from the currently running kernel
	public static string get_kernel_cmdline() {
		string cmdline = fread("/proc/cmdline").strip();
		string result = "";
		foreach (var part in cmdline.split(" ")) {
			// Strip BOOT_IMAGE which is bootloader-specific
			if (!part.has_prefix("BOOT_IMAGE=") && part.length > 0)
				result += part + " ";
		}
		return result.strip();
	}

	// Shell snippet: Save versioned kernel files for a specific version.
	// This now explicitly runs mkinitcpio to ensure the initramfs is correct for the modules.
	public static string shell_save_kernel_version(string version) {
		string s = "";
		s += "# --- Save versioned kernel files for %s ---\n".printf(version);
		s += "BASE_VER=$(echo '%s' | sed -E 's/^([0-9]+(\\.[0-9]+)*).*/\\1/')\n".printf(version);
		s += "KREL=$(ls /usr/lib/modules/ | grep \"^${BASE_VER}\" | sort -V | tail -1)\n";
		s += "if [ -n \"$KREL\" ]; then\n";
		s += "  echo \"Generating versioned initramfs for $KREL...\"\n";
		// BUG4 FIX: also generate fallback initramfs (without autodetect)
		s += "  mkinitcpio -k \"$KREL\" -g \"/boot/initramfs-linux-%s.img\"\n".printf(version);
		s += "  mkinitcpio -k \"$KREL\" -S autodetect -g \"/boot/initramfs-linux-%s-fallback.img\"\n".printf(version);
		// BUG1 FIX: prefer the vmlinuz that the kernel's own package installed under
		// /usr/lib/modules/$KREL/vmlinuz — this guarantees the binary matches the modules.
		// Fall back to /boot/vmlinuz-linux only when that file is absent.
		s += "  if [ -f \"/usr/lib/modules/$KREL/vmlinuz\" ]; then\n";
		s += "    install -m644 \"/usr/lib/modules/$KREL/vmlinuz\" \"/boot/vmlinuz-linux-%s\"\n".printf(version);
		s += "  elif [ -f \"/boot/vmlinuz-linux\" ]; then\n";
		s += "    cp /boot/vmlinuz-linux \"/boot/vmlinuz-linux-%s\"\n".printf(version);
		s += "  else\n";
		s += "    echo \"Warning: vmlinuz for %s not found\" >&2\n".printf(version);
		s += "  fi\n";
		s += "  # Preservation of modules directory via .mainline suffix is removed to follow standard Arch hierarchy.\n";
		s += "  # Older kernels not tracked by pacman are already safe from deletion during updates.\n";
		s += "else\n";
		s += "  echo \"Warning: modules for %s not found, skipping versioning steps\" >&2\n".printf(version);
		s += "fi\n";
		return s;
	}

	// Shell snippet: Restore module directories that were 'saved' to .mainline suffix.
	// This ensures the kernel can actually find its drivers at boot time.
	public static string shell_restore_modules() {
		// Module restoration from .mainline is removed to follow standard Arch hierarchy.
		return "";
	}

	// Shell snippet: remove versioned kernel files.
	// Does NOT update the bootloader — call shell_update_bootloader() once at the end.
	public static string shell_remove_kernel_version(string version) {
		string bootloader = detect_bootloader();
		string s = "";
		s += "# --- Remove versioned kernel files for %s ---\n".printf(version);
		s += "rm -f /boot/vmlinuz-linux-%s\n".printf(version);
		s += "rm -f /boot/initramfs-linux-%s.img\n".printf(version);
		s += "rm -f /boot/initramfs-linux-%s-fallback.img\n".printf(version);
		// Remove both the active modules and the preserved copy
		// BUG3 FIX: normalize version for fgrep, same logic as shell_save_kernel_version
		s += "KVER_NORM=$(echo '%s' | sed 's/\\([0-9]\\)\\.\\(arch\\)/\\1-\\2/')\n".printf(version);
		s += "for MDIR in $(ls /usr/lib/modules/ | grep -F \"$KVER_NORM\"); do\n";
		s += "  rm -rf \"/usr/lib/modules/$MDIR\" || true\n";
		s += "done\n";
		// For systemd-boot, remove the entry file immediately since entries are per-version
		if (bootloader == "systemd-boot") {
			string boot_dir = exists("/boot/loader") ? "/boot" : "/efi";
			s += "rm -f '%s/loader/entries/mainline-linux-%s.conf'\n".printf(boot_dir, version);
		}
		return s;
	}

	// Shell snippet: update the bootloader to reflect current /boot contents.
	// For GRUB: regenerates grub.cfg (detects all vmlinuz-* automatically).
	// For systemd-boot: creates/updates entries for all mainline versioned kernels found.
	public static string shell_update_bootloader() {
		string cmdline = get_kernel_cmdline();
		string s = "# --- Update bootloader (Auto-detecting on host) ---\n";
		
		s += "if [ -f /boot/grub/grub.cfg ]; then\n";
		s += "  echo 'Detected GRUB... updating config'\n";
		s += "  grub-mkconfig -o /boot/grub/grub.cfg\n";
		s += "elif [ -f /boot/grub2/grub.cfg ]; then\n";
		s += "  echo 'Detected GRUB2... updating config'\n";
		s += "  grub-mkconfig -o /boot/grub2/grub.cfg\n";
		s += "elif [ -d /boot/loader/entries ] || [ -d /efi/loader/entries ]; then\n";
		s += "  echo 'Detected systemd-boot... updating entries'\n";
		s += "  BOOT_DIR='/boot'\n";
		s += "  [ -d /efi/loader/entries ] && BOOT_DIR='/efi'\n";
		
		// Find microcode
		s += "  UCODE=''\n";
		s += "  [ -f /boot/intel-ucode.img ] && UCODE='/intel-ucode.img'\n";
		s += "  [ -f /boot/amd-ucode.img ] && UCODE='/amd-ucode.img'\n";

		s += "  # Recreate entries for every kernel found in /boot\n";
		s += "  for KIMG in /boot/vmlinuz-linux*; do\n";
		s += "    [ -f \"$KIMG\" ] || continue\n";
		s += "    KVER=$(basename \"$KIMG\" | sed 's/vmlinuz-linux//' | sed 's/^-//')\n";
		s += "    [ -z \"$KVER\" ] && KVER_TITLE='Standard' || KVER_TITLE=\"$KVER\"\n";
		s += "    [ -z \"$KVER\" ] && KVER_FILE='distro' || KVER_FILE=\"$KVER\"\n";
		s += "    ENTRY=\"$BOOT_DIR/loader/entries/mainline-linux-$KVER_FILE.conf\"\n";
		s += "    echo \"Creating entry: $ENTRY\"\n";
		s += "    echo \"title   Mainline Linux $KVER_TITLE\" > \"$ENTRY\"\n";
		s += "    echo \"linux   /$(basename \\\"$KIMG\\\")\" >> \"$ENTRY\"\n";
		s += "    if [ -n \"$UCODE\" ]; then\n";
		s += "      echo \"initrd  $UCODE\" >> \"$ENTRY\"\n";
		s += "    fi\n";
		s += "    # initrd matches the vmlinuz suffix\n";
		s += "    if [ -z \"$KVER\" ]; then\n";
		s += "      echo \"initrd  /initramfs-linux.img\" >> \"$ENTRY\"\n";
		s += "    else\n";
		s += "      echo \"initrd  /initramfs-linux-$KVER.img\" >> \"$ENTRY\"\n";
		s += "    fi\n";
		s += "    echo \"options %s\" >> \"$ENTRY\"\n".printf(cmdline);
		s += "  done\n";
		s += "else\n";
		s += "  echo 'Warning: unknown bootloader, skipping update' >&2\n";
		s += "fi\n";
		
		return s;
	}



	public static int lock_vlist(bool lck,string list="") {
		return lock_klist(lck,vlist_to_klist(list));
	}

	public static int lock_klist(bool lck,Gee.ArrayList<LinuxKernel> klist) {
		vprint("lock_klist("+lck.to_string()+")",3);
		if (klist.size<1) vprint(_("Lock/Unlock: no kernels specified"));
		int r = 0;
		string action = _("lock");
		if (!lck) action = _("unlock");
		string msg;
		foreach (var k in klist) {
			k.set_locked(lck);
			msg = action + " " + k.name + " ";
			if (k.is_locked==lck) msg += _("ok"); else { msg += _("failed"); r++; }
			vprint(msg);
		}
		return r;
	}

	public static int download_vlist(string list="") {
		return download_klist(vlist_to_klist(list));
	}

	public static int download_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("download_klist()",3);
		if (klist.size<1) vprint(_("Download: no downloadable kernels specified")); 
		int r = 0;
		foreach (var k in klist) if (!k.download_packages()) r++;
		return r;
	}

	public static int install_vlist(string list="") {
		return install_klist(vlist_to_klist(list));
	}

	// dep: pacman
	public static int install_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("install_klist()",3);

		if (!App.try_repo()) return 1;

		string[] flist = {};
		var to_install = new Gee.ArrayList<LinuxKernel>();
		foreach (var k in klist) {
			var v = k.version_main;
			if (k.is_installed) { vprint(_("%s is already installed").printf(v),1,stderr); continue; }
			if (k.is_locked)    { vprint(_("%s is locked").printf(v),1,stderr);            continue; }
			if (k.is_invalid)   { vprint(_("%s is invalid").printf(v),1,stderr);           continue; }
			if (!k.download_packages()) { vprint(_("%s download failed").printf(v),1,stderr); continue; }
			vprint(_("Installing %s").printf(v));
			foreach (var f in k.pkg_url_list.keys) flist += k.CACHE_KDIR+"/"+f;
			to_install.add(k);
		}

		if (flist.length == 0) { vprint(_("Install: no installable kernels specified")); return 1; }

		// Build a root shell script:
		// 1. Save running kernel versioned files (before pacman replaces /boot/vmlinuz-linux)
		// 2. Install via pacman
		// 3. Save newly installed kernel versioned files
		// 4. Update bootloader
		// BUG2 FIX: do NOT use 'set -e' globally. A mkinitcpio failure for an already-installed
		// kernel must not abort the whole script before pacman runs. Instead, use explicit
		// error checks on the critical pacman step only.
		string script = "#!/bin/bash\n\n";

		// Step 1: Install
		foreach (var k in to_install) {
			string k_pkg_args = "";
			foreach (var f in k.pkg_url_list.keys) k_pkg_args += " '%s'".printf(k.CACHE_KDIR+"/"+f);
			script += "# Install kernel %s\n".printf(k.version_main);
			// BUG2 FIX: explicit error check — if pacman fails, abort immediately
			// --overwrite '/usr/lib/modules/*': our versioning script intentionally preserves module
			// directories that belong to previously-installed kernels. When reinstalling one of those
			// kernels pacman would otherwise abort with "file exists in filesystem" because the files
			// are on disk but not registered in the package database. --overwrite tells pacman to just
			// replace them, which is the correct behaviour here.
			script += "pacman -U --noconfirm --overwrite '/usr/lib/modules/*'%s || { echo 'FATAL: pacman install failed' >&2; exit 1; }\n".printf(k_pkg_args);
			script += "\n";
		}

		// Step 2: Save ALL installed kernels' boot files
		foreach (var k in kernel_list) {
			if (k.is_installed) {
				script += "# Ensure kernel %s is versioned and preserved\n".printf(k.version_main);
				script += "if [ ! -f '/boot/vmlinuz-linux-%s' ]; then\n".printf(k.version);
				script += shell_save_kernel_version(k.version);
				script += "fi\n\n";
			}
		}

		foreach (var k in to_install) {
			script += "# Version newly installed kernel %s\n".printf(k.version_main);
			script += shell_save_kernel_version(k.version);
			script += "\n";
		}

		// Step 4: Restore modules and update bootloader
		script += shell_restore_modules();
		script += shell_update_bootloader();
		script += "\n";

		// Write and execute the script with root privileges
		// NOTE: Must use CACHE_DIR (not /tmp) because when running inside Flatpak,
		// /tmp is a private container tmpfs and is NOT visible to flatpak-spawn --host.
		string script_path = Main.CACHE_DIR + "/mainline-install-%s.sh".printf(
			"%08x".printf(Main.rnd.next_int()));
		fwrite(script_path, script);
		vprint("Install script: " + script_path, 3);

		string auth_cmd = sanitize_cmd(wrap_host_cmd(App.auth_cmd)).printf("bash '" + script_path + "'");
		vprint("Executing: " + auth_cmd, 0);
		if (!ask()) { rm(script_path); return 1; }
		var r = Posix.system(auth_cmd);
		rm(script_path);
		if (!App.keep_pkgs) foreach (var f in flist) rm(f);
		return r;
	}

	public static int uninstall_vlist(string list="") {
		return uninstall_klist(vlist_to_klist(list));
	}

	// dep: pacman
	public static int uninstall_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("uninstall_klist()",3);

		string pnames = "";
		var to_remove = new Gee.ArrayList<LinuxKernel>();
		foreach (var k in klist) {
			var v = k.version_main;
			if (k.is_running) { vprint(_("%s is running").printf(v),1,stderr); continue; }
			if (k.is_locked)  { vprint(_("%s is locked").printf(v),1,stderr);  continue; }
			vprint(_("Uninstalling %s").printf(v));
			foreach (var p in k.pkg_list) {
				pnames += " '"+p+"'";
				vprint(_("found")+" : "+p,2);
			}
			to_remove.add(k);
		}
		pnames = pnames.strip();
		if (to_remove.size < 1) { vprint(_("Uninstall: no kernels to remove"),1,stderr); return 1; }
		
		// BUG2 FIX: do NOT use 'set -e' globally (same reason as install_klist)
		string script = "#!/bin/bash\n\n";

		// Step 1: Remove versioned boot files and conditionally uninstall via pacman
		foreach (var k in to_remove) {
			script += "# --- Uninstalling kernel %s ---\n".printf(k.version_main);
			foreach (var p in k.pkg_list) {
				// Only uninstall via pacman if the installed version matches exactly
				script += "if [ \"$(pacman -Q %s 2>/dev/null | cut -d' ' -f2)\" == \"%s\" ]; then\n".printf(p, k.vers);
				script += "  pacman -R --nodeps --noconfirm %s\n".printf(p);
				script += "fi\n";
			}
			// Use k.vers (full version string, e.g. "6.19.14.arch1-1") for boot file removal
			// since that's what the installer uses to name files. Fall back to k.version for
			// mainline kernels where vers may be empty or identical to version.
			string removal_version = (k.vers.length > 0 && k.vers != k.version) ? k.vers : k.version;
			script += shell_remove_kernel_version(removal_version);
			script += "\n";
		}

		// Update modules and bootloader ONCE after all files are removed
		script += shell_restore_modules();
		script += shell_update_bootloader();
		script += "\n";

		// NOTE: Must use CACHE_DIR (not /tmp) — same reason as install_klist above.
		string script_path = Main.CACHE_DIR + "/mainline-uninstall-%s.sh".printf(
			"%08x".printf(Main.rnd.next_int()));
		fwrite(script_path, script);
		vprint("Uninstall script: " + script_path, 3);

		string auth_cmd = sanitize_cmd(wrap_host_cmd(App.auth_cmd)).printf("bash '" + script_path + "'");
		vprint(auth_cmd, 2);
		if (!ask()) { rm(script_path); return 1; }
		var r = Posix.system(auth_cmd);
		rm(script_path);
		return r;
	}

// ---------------------------------------------------------------------
// kunin_old()
// kinst_latest()

	public static int kunin_old() {
		vprint("kunin_old()",3);

		var klist = new Gee.ArrayList<LinuxKernel>();
		bool found_running_kernel = false;

		foreach(var k in kernel_list) {
			if (!k.is_installed) continue;

			var v = k.version_main;

			if (k.is_running) {
				found_running_kernel = true;
				vprint(_("%s is running").printf(v),2);
				continue;
			}
			if (k.compare_to(kernel_latest_installed) >= 0) {
				vprint(_("%s is the highest installed version").printf(v),2);
				continue;
			}
			if (k.is_locked) {
				vprint(_("%s is locked").printf(v),2);
				continue;
			}

			klist.add(k);
		}

		if (!found_running_kernel) {
			vprint(_("Could not find running kernel in list"),1,stderr);
			return 2;
		}

		if (klist.size == 0){
			vprint(_("No old kernels to uninstall"));
			return 0;
		}

		return uninstall_klist(klist);
	}

	public static int kinst_latest(bool minor_only = false) {
		vprint("kinst_latest()",3);

		var k = kernel_update_minor;
		if (!minor_only && kernel_update_major!=null) k = kernel_update_major;

		if (k==null) { vprint(_("No updates")); return 1; }

		var klist = new Gee.ArrayList<LinuxKernel>();
		klist.add(k);
		return install_klist(klist);
	}

}
